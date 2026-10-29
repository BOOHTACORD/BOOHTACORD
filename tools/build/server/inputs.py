"""Release inputs are selected from Git, never from untracked build directories."""
import hashlib
import subprocess
from pathlib import Path
from tools.release.bundle.files import sha256
from tools.release.bundle.manifest import require

SOURCE_PATHS = ("backend", "clients/web", "contracts", "deploy", "tools", ".node-version", "Taskfile.yml",
                "clients/flutter/packages/flutter_webrtc/common/rnnoise/upstream")
TOPOLOGY_PATHS = ("deploy/compose.yaml", "deploy/operators.yaml", "deploy/caddy/Caddyfile",
                  "deploy/livekit/compose.yaml", "deploy/livekit/livekit.yaml", "deploy/livekit/egress.yaml",
                  "deploy/client-updates/catalog.json")
RUNTIME_PATHS = (*TOPOLOGY_PATHS,
                 "tools/release/archive", "tools/release/bundle", "tools/release/install", "tools/release/rollback",
                 "tools/release/rollout/deploy-images.sh", "tools/release/rollout/assert-proxy-networks.sh",
                 "tools/release/rollout/livekit_private_path.py",
                 "tools/release/rollout/align-existing-private-network.py",
                 "tools/release/rollout/postgres_network.py",
                 "tools/release/rollout/reconcile-postgres-credential.py",
                 "tools/ops/attachment_headroom/check-attachment-volume-headroom.sh",
                 "tools/ops/attachment_audit/audit-attachment-volume.sh", "tools/verify/oci/verify_oci.py",
                 "tools/verify/running_images/verify_running.sh")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def source_root(requested):
    root = Path(requested).resolve() if requested is not None else Path(__file__).resolve().parents[3]
    require(Path(git(root, 'rev-parse', '--show-toplevel').decode().strip()).resolve() == root,
            'Builder source must be an exact Git repository root')
    return root


def archive(root, destination, paths):
    with destination.open("wb") as stream:
        subprocess.run(["git", "-C", str(root), "archive", "--format=tar.gz", "HEAD", "--", *paths], stdout=stream, check=True)


def fingerprint(root, paths):
    names = git(root, "ls-files", "-z", "--", *paths).decode().split("\0")
    content = b"".join(name.encode() + b"\0" + git(root, "show", "HEAD:" + name) + b"\0" for name in sorted(filter(None, names)))
    return hashlib.sha256(content).hexdigest()


def compatibility(root):
    migration_root = "backend/internal/database/migrate/migrations/"
    names = git(root, "ls-files", "-z", "--", migration_root).decode().split("\0")
    return {"backend_tree": git(root, "rev-parse", "HEAD:backend").decode().strip(),
            "contracts_sha256": fingerprint(root, ("contracts",)),
            "topology_sha256": fingerprint(root, TOPOLOGY_PATHS),
            "migrations": {Path(name).name: hashlib.sha256(git(root, "show", "HEAD:" + name)).hexdigest()
                           for name in names if name.endswith(".sql")}}
