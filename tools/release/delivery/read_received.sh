#!/usr/bin/env bash
set -euo pipefail
revision="$1"; driver_sha="$2"; controller="$3"; nonce="$4"
[[ "$revision" =~ ^[0-9a-f]{40}$ && "$driver_sha" =~ ^[0-9a-f]{64}$ && "$controller" =~ ^[0-9a-f]{40}$ && "$nonce" =~ ^[0-9a-f]{32}$ ]]
stage="/tmp/voice-platform-delivery-$nonce"
[[ -d "$stage" && ! -L "$stage" && "$(stat -c '%a' "$stage")" == 700 && "$(stat -c '%u' "$stage")" == "${SUDO_UID:?}" ]]
driver="$stage/$revision.installer.tar.gz"
[[ -f "$driver" && ! -L "$driver" && "$(stat -c '%h' "$driver")" == 1 ]]
printf '%s  %s\n' "$driver_sha" "$driver" | sha256sum -c - >/dev/null
temporary="$(mktemp -d /opt/voice-platform-readback.XXXXXX)"
trap 'rm -rf "$temporary"' EXIT
tar -xzf "$driver" -C "$temporary" --no-same-owner
cd "$temporary"
python3 -m tools.release.install.readback "$revision" --controller-revision "$controller" --nonce "$nonce" </dev/null
# Only this attempt's successfully acknowledged transport copies are removed.
rm -f -- "$stage/$revision.release.tar.gz" "$driver"
rmdir -- "$stage"
