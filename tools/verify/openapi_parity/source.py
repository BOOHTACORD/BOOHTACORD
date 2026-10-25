"""Read native Go route evidence and exact handler request edges."""
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
LEAF = Path(__file__).resolve().parent
PRIVATE = {"GET /metrics", "GET /internal/media-admission", "POST /internal/livekit/roster", "POST /internal/telemetry/metrics"}


def routes():
    files = [str(LEAF / name) for name in ("source.go", "bindings.go", "extract.go")]
    output = subprocess.run(["go", "run", *files], cwd=ROOT, capture_output=True,
                            text=True, check=True).stdout
    result = json.loads(output)
    keys = [key(route) for route in result]
    if len(keys) != len(set(keys)):
        raise ValueError("duplicate native route")
    return result


def key(route):
    return route["method"] + " " + route["path"]


def functions(directory):
    result = {}
    for path in sorted((ROOT / directory).glob("*.go")):
        if path.name.endswith("_test.go"):
            continue
        text = path.read_text(encoding="utf-8-sig")
        matches = list(re.finditer(r"(?m)^func (?:\([^\n]*\) )?(\w+)\(", text))
        for index, match in enumerate(matches):
            end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
            result[match[1]] = text[match.start():end]
    return result


def handler_source(route):
    expression = route["expression"]
    result = []
    for directory in route["packages"]:
        if directory.endswith(("/postgres", "/livekit")) or directory.endswith("authenticate_session/api"):
            continue
        definitions = functions(directory)
        # Names in the resolved registration select constructors and receiver methods.
        pending = [name for name in definitions if re.search(r"\." + name + r"\b", expression)]
        if re.search(r'\bHandler\s*\{', expression) and 'ServeHTTP' in definitions:
            pending.append('ServeHTTP')
        visited = set()
        while pending:
            name = pending.pop()
            if name in visited:
                continue
            visited.add(name)
            text = definitions[name]
            result.append(text)
            for candidate in definitions:
                if re.search(r"\b" + candidate + r"\s*\(", text) and candidate not in visited:
                    pending.append(candidate)
            if re.search(r"\b[Hh]andler\s*\{", text) and "ServeHTTP" in definitions:
                pending.append("ServeHTTP")
    return "\n".join(result)


def request_parameters(route):
    text = handler_source(route)
    query_names = set(re.findall(r"\.URL\.Query\(\)\.(?:Get|Has)\(\"([^\"]+)\"", text))
    aliases = set(re.findall(r"(\w+)\s*:?=\s*\w+\.URL\.Query\(\)", text))
    # url.Values helpers are part of the same exact API leaf.
    aliases.update(re.findall(r"\b(\w+)\s+url\.Values", text))
    # Literal call sites of local helpers that index Query()[name].
    helpers = re.findall(r'func (\w+)\([^\n]*name string[^\n]*\)[^{]*\{[^}]*\.URL\.Query\(\)\[name\]', text)
    for helper in helpers:
        query_names.update(re.findall(r'\b' + helper + r'\(\w+, "([^\"]+)"\)', text))
    for alias in aliases:
        query_names.update(re.findall(r"\b" + alias + r'\.(?:Get|Has)\("([^\"]+)"', text))
        query_names.update(re.findall(r"\b" + alias + r'\["([^\"]+)"\]', text))
    header_names = set(re.findall(r'\b\w+\.Header\.Get\("([^\"]+)"', text))
    header_names.discard("Content-Type")  # OpenAPI requestBody declares media type.
    if route["path"] == "/api/v1/realtime":
        diagnostic = (ROOT / "backend/internal/identity/authenticate_session/api/diagnostic_headers.go").read_text()
        query_names.update(re.findall(r'"X-[^\"]+": "([^\"]+)"', diagnostic))
        tracing = (ROOT / "backend/internal/observability/trace_http/w3c_context.go").read_text()
        query_names.update(re.findall(r'\.URL\.Query\(\)\.Get\("([^\"]+)"', tracing))
        header_names.add("Origin")
    return query_names, header_names


def authenticated(route):
    return route["session_required"]


def origin_required(route):
    return route["method"] in {"POST", "PUT", "PATCH", "DELETE"}
