"""Validate committed runtime declarations against the central version policy."""
import json
import re
from pathlib import Path


def check_versions(root: Path, versions: dict) -> list[str]:
    errors = []
    web = root / "clients/web"
    required = {
        root / ".node-version": versions["node"],
        web / "Dockerfile": f"FROM node:{versions['node']}-alpine",
        root / "backend/Dockerfile": f"FROM golang:{versions['go']}-alpine",
        root / "backend/go.mod": f"toolchain go{versions['go']}",
    }
    for path, expected in required.items():
        if not path.exists() or expected not in path.read_text(encoding="utf-8"):
            errors.append(f"{path.relative_to(root)} must declare {expected}")
    for path in (root / ".github/workflows").glob("*.y*ml"):
        text = path.read_text(encoding="utf-8")
        for kind in ("node", "go", "flutter"):
            pattern = rf"(?m)^\s*{kind}-version:\s*['\"]?([^\s'\"#]+)"
            for actual in re.findall(pattern, text):
                if actual != versions[kind]:
                    errors.append(f"{path.name}: {kind} {actual} != {versions[kind]}")
        for actual in re.findall(r"(?m)^\s*node-version-file:\s*['\"]?([^\s'\"#]+)", text):
            if actual != ".node-version":
                errors.append(f"{path.name}: use the root .node-version")
    return errors


def main():
    root = Path(__file__).resolve().parents[3]
    versions = json.loads((root / "tools/toolchains.json").read_text(encoding="utf-8"))
    errors = check_versions(root, versions)
    for error in errors:
        print(error)
    if not errors:
        print("Committed toolchain declarations agree")
    if not errors:
        from tools.ci.toolchains.auxiliary import main as audit_auxiliary
        audit_auxiliary()
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
