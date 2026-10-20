#!/usr/bin/env bash
set -euo pipefail
revision="$1"; bundle_sha="$2"; driver_sha="$3"; current="$4"; controller="$5"; nonce="$6"
[[ "$revision" =~ ^[0-9a-f]{40}$ && "$bundle_sha" =~ ^[0-9a-f]{64}$ && "$driver_sha" =~ ^[0-9a-f]{64}$ ]]
[[ "$current" =~ ^[0-9a-f]{40}$ && "$controller" =~ ^[0-9a-f]{40}$ && "$nonce" =~ ^[0-9a-f]{32}$ ]]
stage="/tmp/voice-platform-delivery-$nonce"
[[ -d "$stage" && ! -L "$stage" && "$(stat -c '%a' "$stage")" == 700 && "$(stat -c '%u' "$stage")" == "${SUDO_UID:?}" ]]
bundle="$stage/$revision.release.tar.gz"
driver="$stage/$revision.installer.tar.gz"
for path in "$bundle" "$driver"; do
  [[ -f "$path" && ! -L "$path" && "$(stat -c '%h' "$path")" == 1 ]]
done
[[ -r /etc/voice-platform/release-signing.pub.pem ]]
printf '%s  %s\n' "$bundle_sha" "$bundle" "$driver_sha" "$driver" | sha256sum -c -
temporary="$(mktemp -d /opt/voice-platform-installer.XXXXXX)"
trap 'rm -rf "$temporary"' EXIT
tar -xzf "$driver" -C "$temporary" --no-same-owner
cd "$temporary"
source tools/release/install/invocation.sh
run_received_installer "$bundle" "$revision" "$bundle_sha" "$current" "$temporary"
# Keep only this attempt's transport until a separate fresh readback acknowledges it.
