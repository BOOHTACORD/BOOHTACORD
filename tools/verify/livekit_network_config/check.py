"""Check private LiveKit wiring and hashes recorded in its evidence."""
import hashlib
import json
from pathlib import Path

import yaml

from .model import metrics_reachable_peers, validate


def read(root, path):
    with (root / path).open(encoding="utf-8") as source:
        return yaml.safe_load(source)


def load_configs(root):
    livekit = read(root, "deploy/livekit/livekit.yaml")
    deploy = read(root, "deploy/compose.yaml")
    for path in ("deploy/operators.yaml", "deploy/livekit/compose.yaml"):
        included = read(root, path)
        deploy["services"].update(included.get("services", {}))
        deploy["networks"].update(included.get("networks", {}))
    observability = read(root, "docker/observability/compose.yaml")
    prometheus = read(root, "docker/observability/prometheus.yaml")
    alerts = read(root, "docker/observability/livekit-network-alerts.yaml")
    return livekit, deploy, observability, prometheus, alerts


def main():
    root = Path(__file__).resolve().parents[3]
    livekit, deploy, observability, prometheus, alerts = load_configs(root)
    validate(livekit, deploy, observability, prometheus, alerts)
    peers = ", ".join(sorted(metrics_reachable_peers(deploy, observability)))
    evidence_path = root / "evidence/media/livekit-network-config-2026-10-07.json"
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    # Historical deployment evidence stays immutable; later source-only revalidation
    # records intentional alert wiring changes without claiming a new physical probe.
    current = root / "evidence/media/livekit-network-config-2026-10-08-roster-alerts.json"
    revalidation = json.loads(current.read_text(encoding="utf-8"))
    telemetry = read(root, "evidence/media/livekit-network-config-2026-10-21-telemetry.json")
    expected_artifacts = (evidence["repository_artifacts"] | revalidation["repository_artifacts"]
                          | telemetry["repository_artifacts"])
    for path, expected in expected_artifacts.items():
        content = (root / path).read_bytes().replace(b"\r\n", b"\n")
        actual = hashlib.sha256(content).hexdigest()
        if expected != f"sha256:{actual}":
            raise ValueError(f"repository artifact hash differs for {path}")
    print(f"LiveKit metrics peer set: {peers}")
    print("LiveKit ports, peer boundary, metric labels, allowlist, and alert are valid")


if __name__ == "__main__":
    main()
