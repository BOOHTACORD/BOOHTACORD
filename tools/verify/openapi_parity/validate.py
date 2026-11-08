"""Validate public route/security/request parity against native Go evidence."""
import json
import re
from .source import ROOT, PRIVATE, routes, key, authenticated, origin_required, request_parameters

METHODS = {"get", "post", "put", "patch", "delete", "head", "options"}


def resolve(document, value):
    if "$ref" not in value:
        return value
    reference = value["$ref"]
    if not reference.startswith("#/"):
        raise ValueError("external reference unsupported: " + reference)
    result = document
    for part in reference[2:].split("/"):
        result = result[part.replace("~1", "/").replace("~0", "~")]
    return result


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(document, native):
    schemes = document["components"].get("securitySchemes", {})
    scheme = schemes.get("SessionCookie", {})
    require((scheme.get("type"), scheme.get("in"), scheme.get("name")) ==
            ("apiKey", "cookie", "vp_session"), "cookie security scheme must match native session")
    operations = {method.upper() + " " + path: operation
                  for path, item in document["paths"].items()
                  for method, operation in item.items() if method in METHODS}
    public = {key(route): route for route in native if key(route) not in PRIVATE}
    require(set(operations) == set(public), "route parity missing/extra: " + str(set(operations) ^ set(public)))
    identifiers = [operation.get("operationId") for operation in operations.values()]
    require(None not in identifiers and len(set(identifiers)) == len(identifiers), "operationId missing/duplicate")
    for name, route in public.items():
        operation = operations[name]
        expected = [{"SessionCookie": []}] if authenticated(route) else []
        require(operation.get("security") == expected, name + ": security parity")
        parameters = [resolve(document, p) for p in operation.get("parameters", [])]
        actual = {(p["in"], p["name"]) for p in parameters}
        require(len(actual) == len(parameters), name + ": duplicate parameter")
        query, headers = request_parameters(route)
        if origin_required(route):
            headers.add("Origin")
        expected_parameters = ({("path", value) for value in re.findall(r"\{([^}]+)\}", route["path"])} |
                               {("query", value) for value in query} | {("header", value) for value in headers})
        require(actual == expected_parameters, name + ": parameter parity " + str(actual ^ expected_parameters))
        for parameter in parameters:
            identity = parameter["in"], parameter["name"]
            required = (identity[0] == "path" or identity in {("header", "X-Account-ID"),
                        ("header", "X-Screen-Preview-Revision"), ("header", "X-Client-Platform"), ("header", "X-Voice-Sound-Account")} or
                        identity == ("header", "Origin") and origin_required(route) or
                        route["path"] == "/api/v1/client-updates")
            require(parameter.get("required", False) == required, name + ": required parameter " + str(identity))
            require("schema" in parameter and "type" in resolve(document, parameter["schema"]), name + ": parameter schema")
        for status, response in operation["responses"].items():
            response = resolve(document, response)
            require("description" in response, name + ": response description " + status)
            require("X-Request-ID" in response.get("headers", {}), name + ": request ID response " + status)
            for media in response.get("content", {}).values():
                require("schema" in media, name + ": response schema " + status)
                resolve(document, media["schema"])
        check_responses(document, operation, route)
    lint_refs(document, document)
    return len(public)


def check_responses(document, operation, route):
    responses = operation["responses"]
    required = {"500"}
    if authenticated(route):
        required.add("401")
    if origin_required(route):
        required.add("403")
    require(required <= set(responses), key(route) + ": middleware statuses")
    if route["path"] == "/api/v1/auth/session":
        require("401" not in responses and not responses["500"].get("content"), "optional session response semantics")
        require(responses["200"]["content"]["application/json"]["schema"] ==
                {"$ref": "#/components/schemas/SessionStatus"}, "optional session success body")
    if route["path"] == "/api/v1/telemetry/traces":
        for status in ("400", "413", "415", "503"):
            require(not responses[status].get("content"), "relay " + status + " must have empty body")
        for status in ("401", "429"):
            require(responses[status]["content"]["application/json"]["schema"] ==
                    {"$ref": "#/components/schemas/Error"}, "relay JSON error " + status)
        require("Retry-After" in responses["429"]["headers"], "rate limit Retry-After")
    if route["path"] == "/api/v1/voice/screen-metrics":
        require(not responses["400"].get("content"), "screen report 400 must have empty body")
    if route["path"] == "/api/v1/client-updates":
        for status in ("400", "503", "500"):
            require(responses[status]["content"]["application/json"]["schema"] ==
                    {"$ref": "#/components/schemas/ClientUpdateError"}, "flat client-update error " + status)


def lint_refs(document, value):
    if isinstance(value, dict):
        if "$ref" in value:
            resolve(document, value)
        for child in value.values():
            lint_refs(document, child)
    elif isinstance(value, list):
        for child in value:
            lint_refs(document, child)


if __name__ == "__main__":
    count = validate(json.loads((ROOT / "contracts/openapi.yaml").read_text(encoding="utf-8-sig")), routes())
    print(f"OpenAPI parity OK: {count} public operations; {len(PRIVATE)} private exclusions.")
