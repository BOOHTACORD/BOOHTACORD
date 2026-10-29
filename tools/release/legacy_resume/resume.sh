#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'resume-built-release: %s\n' "$1" >&2
  exit 1
}

sha="${1:-}"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || fail 'expected a 40-character lowercase commit SHA'

release_root="${VOICE_PLATFORM_RELEASE_ROOT:-/opt/voice-platform-releases}"
[[ "$release_root" == /* && -d "$release_root" ]] || fail 'release root is unavailable'
release_dir="$release_root/$sha"
compose_file="$release_dir/deploy/compose.yaml"
[[ -f "$compose_file" ]] || compose_file="$release_dir/compose.yaml"
[[ -f "$compose_file" && -f "$release_dir/.env" ]] || fail 'built release is unavailable'

scripts=()
for relative in tools/ops/attachment_headroom/check-attachment-volume-headroom.sh tools/release/rollout/deploy-images.sh tools/ops/attachment_audit/audit-attachment-volume.sh; do
  script="$release_dir/$relative"
  [[ -f "$script" ]] || script="$release_dir/scripts/${relative##*/}"
  [[ -f "$script" ]] || fail "release script is unavailable: $relative"
  scripts+=("$script")
done

# A failed capacity check must stop before any image lookup or deployment mutation.
bash "${scripts[0]}"

api_image="voice-platform-api:$sha"
web_image="voice-platform-web:$sha"
docker image inspect "$api_image" >/dev/null || fail "built image is unavailable: $api_image"
docker image inspect "$web_image" >/dev/null || fail "built image is unavailable: $web_image"

VOICE_PLATFORM_DIR="$release_dir" API_IMAGE="$api_image" WEB_IMAGE="$web_image" \
  bash "${scripts[1]}"
bash "${scripts[2]}" "$sha"
