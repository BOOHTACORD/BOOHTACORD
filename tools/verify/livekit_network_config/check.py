"""Check private LiveKit wiring and hashes recorded in its evidence."""
import hashlib
import json
from pathlib import Path

import yaml

from .model import metrics_reachable_peers, validate
from .historical_artifact import evidence_content
from .recovery_evidence import verify_recovery_evidence

# The latest source-only evidence was recorded against this merged revision.
HISTORICAL_EVIDENCE_REVISION = 'c875c5d686f99d47ca28c511eecd5213c7a3319a'


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
    # records intentional monitoring wiring changes without claiming a physical probe.
    current = root / "evidence/media/livekit-network-config-2026-10-08-roster-alerts.json"
    revalidation = json.loads(current.read_text(encoding="utf-8"))
    telemetry = read(root, "evidence/media/livekit-network-config-2026-10-21-telemetry.json")
    observability = read(root, "evidence/media/livekit-network-config-2026-10-22-observability.json")
    notifications = read(root, "evidence/media/livekit-network-config-2026-10-25-notifications.json")
    screen_previews = read(root, "evidence/media/livekit-network-config-2026-10-29-screen-previews.json")
    explicit_node_ip = read(root, "evidence/media/livekit-network-config-2026-11-01-explicit-node-ip.json")
    rtc_network = read(root, "evidence/media/livekit-rtc-network-2026-11-01.json")
    history_edit = read(root, "evidence/media/livekit-network-history-edit-2026-11-03.json")
    egress = read(root, "evidence/media/livekit-network-config-2026-11-04-egress.json")
    voice_recovery = read(root, "evidence/media/livekit-network-voice-recovery-2026-11-04.json")
    merged_sources = read(root, "evidence/media/livekit-network-history-merge-2026-11-04.json")
    audio_coexistence = read(root, "evidence/media/livekit-network-audio-coexistence-2026-11-05.json")
    release_headroom = read(root, "evidence/media/livekit-network-release-headroom-2026-11-05.json")
    audio_check = read(root, "evidence/media/livekit-network-audio-check-2026-11-05.json")
    android_network_loss = read(root, "evidence/media/livekit-android-network-loss-2026-11-06.json")
    roster_revalidation = read(root, "evidence/media/livekit-network-roster-2026-11-07.json")
    sound_revalidation = read(root, "evidence/media/livekit-network-sound-policy-2026-11-07.json")
    sound_preferences = read(root, "evidence/media/livekit-network-sound-preferences-2026-11-07.json")
    sound_flutter = read(root, "evidence/media/livekit-network-sound-flutter-2026-11-07.json")
    sound_concurrency = read(root, "evidence/media/livekit-network-sound-concurrency-2026-11-07.json")
    sound_native_api = read(root, "evidence/media/livekit-network-sound-native-api-2026-11-07.json")
    sound_native_fence = read(root, "evidence/media/livekit-network-sound-native-fence-2026-11-07.json")
    sound_native_controller = read(root, "evidence/media/livekit-network-sound-native-controller-2026-11-07.json")
    sound_web_safety = read(root, "evidence/media/livekit-network-sound-web-safety-2026-11-07.json")
    sound_web_controls = read(root, "evidence/media/livekit-network-sound-web-controls-2026-11-07.json")
    sound_web_queue = read(root, "evidence/media/livekit-network-sound-web-queue-2026-11-07.json")
    sound_web_loader = read(root, "evidence/media/livekit-network-sound-web-loader-2026-11-07.json")
    sound_integration = read(root, "evidence/media/livekit-network-sound-integration-2026-11-07.json")
    welcome_revalidation = read(root, "evidence/media/livekit-network-welcome-2026-11-07.json")
    welcome_parity = read(root, "evidence/media/livekit-network-welcome-parity-2026-11-07.json")
    welcome_windows = read(root, "evidence/media/livekit-network-welcome-windows-2026-11-07.json")
    expected_artifacts = (evidence["repository_artifacts"] | revalidation["repository_artifacts"]
                          | telemetry["repository_artifacts"] | observability["repository_artifacts"]
                          | notifications["repository_artifacts"] | screen_previews["repository_artifacts"]
                          | explicit_node_ip["repository_artifacts"]
                          | rtc_network["repository_artifacts"] | history_edit["repository_artifacts"]
                          | egress["repository_artifacts"] | voice_recovery["repository_artifacts"]
                          | merged_sources["repository_artifacts"]
                          | audio_coexistence["repository_artifacts"]
                          | release_headroom["repository_artifacts"]
                          | audio_check["repository_artifacts"]
                          | android_network_loss["repository_artifacts"]
                          | sound_revalidation["repository_artifacts"]
                          | sound_preferences["repository_artifacts"]
                          | sound_flutter["repository_artifacts"] | sound_concurrency["repository_artifacts"]
                          | sound_native_api["repository_artifacts"] | sound_native_fence["repository_artifacts"]
                          | sound_native_controller["repository_artifacts"] | sound_web_safety["repository_artifacts"]
                          | sound_web_controls["repository_artifacts"] | sound_web_queue["repository_artifacts"]
                          | sound_web_loader["repository_artifacts"] | sound_integration["repository_artifacts"]
                          | roster_revalidation["repository_artifacts"]
                          | welcome_revalidation["repository_artifacts"] | welcome_parity["repository_artifacts"] | welcome_windows["repository_artifacts"] )
    release_metadata = read(root, "evidence/media/livekit-network-release-metadata-2026-11-08.json")
    expected_artifacts |= release_metadata["repository_artifacts"]
    chat_ux_metadata = read(root, "evidence/media/livekit-network-release-metadata-2026-11-09-chat-ux.json")
    expected_artifacts |= chat_ux_metadata["repository_artifacts"]
    roster_ws_source = read(root, "evidence/media/livekit-network-roster-ws-source-2026-11-09.json")
    expected_artifacts |= roster_ws_source["repository_artifacts"]
    recovery_review = read(root, "evidence/media/livekit-network-recovery-review-2026-11-09.json")
    verify_recovery_evidence(root, recovery_review["repository_artifacts"])
    for path, expected in expected_artifacts.items():
        content = evidence_content(root, HISTORICAL_EVIDENCE_REVISION, path)
        content = content.replace(b"\r\n", b"\n")
        actual = hashlib.sha256(content).hexdigest()
        if expected != f"sha256:{actual}":
            raise ValueError(f"repository artifact hash differs for {path}")
    print(f"LiveKit metrics peer set: {peers}")
    print("LiveKit ports, peer boundary, metric labels, allowlist, and alert are valid")


if __name__ == "__main__":
    main()
