"""Trusted-builder entrypoint. Production installation never calls this module."""
import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from tools.release.archive.extract import extract
from tools.release.bundle.files import sha256
from tools.release.bundle.manifest import require
from tools.release.bundle.package import package
from tools.audio.asset_build import build_assets
from .buildx import configure
from .images import build
from .inputs import RUNTIME_PATHS, SOURCE_PATHS, archive, compatibility, git, source_root
from .smoke import run_smoke


def gate_receipts(directory, revision):
    checks = {}
    for gate in ("backend", "web", "contracts"):
        receipt = json.loads((directory / (gate + ".json")).read_text(encoding="utf-8"))
        require(receipt.get("source_revision") == revision, "Gate receipt belongs to another source revision")
        require(receipt.get("gate") == gate and receipt.get("status") == "PASS", "Release gate did not pass: " + gate)
        checks[gate] = "PASS"
    return checks


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checks", type=Path, required=True)
    parser.add_argument("--signing-key", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path(".out/releases"))
    parser.add_argument("--source", type=Path, help="Exact clean Git source root; defaults to this builder repository")
    args = parser.parse_args()
    require(sys.platform == "linux", "Server builder requires Linux with Docker OCI image storage")
    root = source_root(args.source)
    revision = git(root, "rev-parse", "HEAD").decode().strip()
    require(not git(root, "diff", "HEAD", "--"), "Builder requires a clean tracked checkout")
    checks = gate_receipts(args.checks.resolve(), revision)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    bundle = output / revision
    bundle.mkdir(exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="builder-", dir=output) as temporary:
        temporary = Path(temporary)
        source_archive = temporary / "source.tar.gz"
        archive(root, source_archive, SOURCE_PATHS)
        source_hash = sha256(source_archive)
        source = temporary / "source"
        extract(source_archive, source, max_bytes=200_000_000)
        build_assets(source)
        environment = configure(root, temporary / "docker")
        receipts = build(source, bundle, revision, source_hash, environment)
        binaries = temporary / "operators"
        binaries.mkdir()
        run_smoke(receipts, binaries)
        checks["artifact_smoke"] = "PASS"
        archive(root, bundle / "runtime.tar.gz", RUNTIME_PATHS)
        destination = package(bundle, revision, source_hash, receipts, compatibility(root),
                              {"source_revision": revision, "checks": checks}, args.signing_key.resolve())
        print("Verified release bundle: " + str(destination))


if __name__ == "__main__":
    main()
