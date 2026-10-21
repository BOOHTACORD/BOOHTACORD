#!/usr/bin/env bash
set -euo pipefail
failure_phase=remote_setup
report_failure() {
  printf '{"schema_version":1,"kind":"install-result","status":"FAIL","phase":"%s"}\n' "$failure_phase"
  exit 0
}
trap report_failure ERR
failure_phase=remote_arguments
if [[ "$#" -ne 6 ]]; then report_failure; fi
revision="$1"; bundle_sha="$2"; driver_sha="$3"; current="$4"; controller="$5"; nonce="$6"
if ! [[ "$revision" =~ ^[0-9a-f]{40}$ && "$bundle_sha" =~ ^[0-9a-f]{64}$ && "$driver_sha" =~ ^[0-9a-f]{64}$ ]]; then report_failure; fi
if ! [[ "$current" =~ ^[0-9a-f]{40}$ && "$controller" =~ ^[0-9a-f]{40}$ && "$nonce" =~ ^[0-9a-f]{32}$ ]]; then report_failure; fi
stage="/tmp/voice-platform-delivery-$nonce"
failure_phase=remote_stage
if [[ -z "${SUDO_UID:-}" ]] || ! [[ -d "$stage" && ! -L "$stage" && "$(stat -c '%a' "$stage")" == 700 && "$(stat -c '%u' "$stage")" == "$SUDO_UID" ]]; then report_failure; fi
bundle="$stage/$revision.release.tar.gz"
driver="$stage/$revision.installer.tar.gz"
failure_phase=remote_files
for path in "$bundle" "$driver"; do
  if ! [[ -f "$path" && ! -L "$path" && "$(stat -c '%h' "$path")" == 1 ]]; then report_failure; fi
done
failure_phase=remote_trust
if ! [[ -r /etc/voice-platform/release-signing.pub.pem ]]; then report_failure; fi
failure_phase=remote_checksum
printf '%s  %s\n' "$bundle_sha" "$bundle" "$driver_sha" "$driver" | sha256sum -c - >/dev/null 2>&1
failure_phase=installer_workspace
temporary="$(mktemp -d /opt/voice-platform-installer.XXXXXX)"
trap 'rm -rf "$temporary"' EXIT
failure_phase=driver_extract
tar -xzf "$driver" -C "$temporary" --no-same-owner >/dev/null 2>&1
cd "$temporary"
failure_phase=installer_bootstrap
source tools/release/install/invocation.sh
run_received_installer "$bundle" "$revision" "$bundle_sha" "$current" "$temporary"
# Keep only this attempt's transport until a separate fresh readback acknowledges it.
