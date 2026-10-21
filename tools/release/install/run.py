"""Install already-built, signed artifacts. Requires provisioned host trust and runtime."""
import argparse
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from tools.release.archive.extract import extract
from tools.release.bundle.compatibility import compatible_upgrade
from tools.release.bundle.files import sha256
from tools.release.bundle.manifest import require
from tools.release.bundle.verify import verify_bundle
from .docker import deploy, docker, load_images, verify_running
from .guards import disk_budget
from .locking import installation_lock
from .runtime import check_expanded, prepare_environment
from .state import current_manifest, write_receipt
from .diagnostics import FailureReceipt
from . import observation, readback


def install(args, *, diagnostics=None):
    mark = diagnostics.mark if diagnostics is not None else lambda phase: None
    mark('argument_validation')
    require(re.fullmatch(r"[0-9a-f]{40}", args.revision), "Full revision is required")
    require(re.fullmatch(r"[0-9a-f]{64}", args.sha256), "Bundle checksum is required")
    mark('bundle_checksum')
    require(args.bundle.is_file() and sha256(args.bundle) == args.sha256, "Transferred bundle checksum differs")
    root = args.release_root.resolve()
    mark('release_lock')
    with installation_lock(root):
        mark('disk_budget')
        disk_budget(shutil.disk_usage(root).free, args.bundle.stat().st_size)
        mark('docker_preflight')
        docker_root = Path(docker("info", "--format", "{{.DockerRootDir}}"))
        mark('disk_budget')
        disk_budget(shutil.disk_usage(docker_root).free, args.bundle.stat().st_size)
        with tempfile.TemporaryDirectory(prefix=".incoming.", dir=root) as staging:
            incoming = Path(staging) / "bundle"
            mark('bundle_extract')
            extract(args.bundle, incoming, max_bytes=min(8_000_000_000, shutil.disk_usage(root).free - 2_147_483_648))
            mark('bundle_verification')
            manifest = verify_bundle(incoming, args.public_key, args.revision)
            mark('running_release_check')
            current = current_manifest(root, args.public_key)
            expected_current = getattr(args, 'expected_current_revision', None)
            require(expected_current is None or current['source_revision'] == expected_current,
                    'Running source changed while delivery was waiting; rerun preflight')
            mark('compatibility_check')
            compatible_upgrade(current, manifest)
            mark('state_observation')
            before = {'volumes': observation.volumes(), 'schema_sha256': observation.schema()}
            runtime = Path(staging) / "runtime"
            mark('runtime_extract')
            extract(incoming / "runtime.tar.gz", runtime, max_bytes=100_000_000)
            mark('attachment_headroom')
            subprocess.run(["bash", str(runtime / "tools/ops/attachment_headroom/check-attachment-volume-headroom.sh")], check=True)
            mark('release_directory')
            destination = root / args.revision
            if destination.exists():
                existing = verify_bundle(destination, args.public_key, args.revision)
                require(existing == manifest, "Immutable release directory contains another artifact")
                check_expanded(destination, runtime)
            else:
                for path in runtime.iterdir():
                    require(not (incoming / path.name).exists(), "Runtime payload conflicts with release artifacts")
                    path.rename(incoming / path.name)
                incoming.rename(destination)
            mark('environment_prepare')
            prepare_environment(destination, args.environment)
            mark('image_load')
            load_images(destination, manifest)
            mark('deployment')
            intervals = deploy(destination, manifest)
            mark('runtime_verification')
            verify_running(destination, manifest)
            mark('readback')
            readback.record(destination, manifest, current, before, rollout=intervals)
            mark('installation_receipt')
            write_receipt(destination, manifest)
            print("Installed verified source revision " + args.revision)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("revision")
    parser.add_argument("sha256")
    parser.add_argument("--release-root", type=Path, default=Path("/opt/voice-platform-releases"))
    parser.add_argument("--environment", type=Path, default=Path("/opt/voice-platform/.env"))
    parser.add_argument("--public-key", type=Path, default=Path("/etc/voice-platform/release-signing.pub.pem"))
    parser.add_argument("--expected-current-revision")
    parser.add_argument("--failure-receipt", type=Path)
    args = parser.parse_args()
    diagnostics = FailureReceipt(args.failure_receipt)
    try:
        install(args, diagnostics=diagnostics)
    except Exception:
        diagnostics.write()
        raise


if __name__ == "__main__":
    main()
