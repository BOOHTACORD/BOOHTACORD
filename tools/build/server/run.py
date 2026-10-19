"""Trusted-builder entrypoint. Production installation never calls this module."""
import argparse
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
from .gate_receipts import read as gate_receipts
from .metrics import Metrics


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
    metrics=Metrics(output/(revision+'.build.json'),revision)
    with tempfile.TemporaryDirectory(prefix="builder-", dir=output) as temporary:
        temporary = Path(temporary)
        source_archive = temporary / "source.tar.gz"
        with metrics.stage('source_archive'):
            archive(root, source_archive, SOURCE_PATHS)
            source_hash = sha256(source_archive)
            metrics.value['source_archive_sha256']=source_hash
        source = temporary / "source"
        with metrics.stage('source_extract'):
            extract(source_archive, source, max_bytes=200_000_000)
        with metrics.stage('assets'):build_assets(source)
        with metrics.stage('buildx_setup'):environment = configure(root, temporary / "docker")
        with metrics.stage('images'):
            receipts = build(source, bundle, revision, source_hash, environment,metrics=metrics)
        binaries = temporary / "operators"
        binaries.mkdir()
        with metrics.stage('smoke'):run_smoke(receipts, binaries)
        checks["artifact_smoke"] = "PASS"
        with metrics.stage('runtime_archive'):archive(root, bundle / "runtime.tar.gz", RUNTIME_PATHS)
        destination = package(bundle, revision, source_hash, receipts, compatibility(root),
                              {"source_revision": revision, "checks": checks}, args.signing_key.resolve(),measure=metrics.stage)
        metrics.complete({name:row['index_digest'] for name,row in receipts.items()})
        print("Verified release bundle: " + str(destination))


if __name__ == "__main__":
    main()
