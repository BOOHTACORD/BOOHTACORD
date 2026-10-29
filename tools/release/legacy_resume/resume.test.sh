#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
script="$root/tools/release/legacy_resume/resume.sh"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
sha=0123456789abcdef0123456789abcdef01234567
release_root="$fixture/voice-platform-releases"
release_dir="$release_root/$sha"
mkdir -p "$release_dir/scripts" "$fixture/bin"
printf 'services: {}\n' > "$release_dir/compose.yaml"
printf 'PUBLIC_HOST=example.test\n' > "$release_dir/.env"

mkdir -p "$release_dir/tools/ops/attachment_headroom"
cat > "$release_dir/tools/ops/attachment_headroom/check-attachment-volume-headroom.sh" <<'EOF'
#!/usr/bin/env bash
printf 'guard\n' >> "$TEST_LOG"
[[ "${TEST_FAIL_GUARD:-0}" != 1 ]]
EOF
mkdir -p "$release_dir/tools/release/rollout"
cat > "$release_dir/tools/release/rollout/deploy-images.sh" <<'EOF'
#!/usr/bin/env bash
printf 'deploy:%s:%s:%s\n' "$VOICE_PLATFORM_DIR" "$API_IMAGE" "$WEB_IMAGE" >> "$TEST_LOG"
EOF
mkdir -p "$release_dir/tools/ops/attachment_audit"
cat > "$release_dir/tools/ops/attachment_audit/audit-attachment-volume.sh" <<'EOF'
#!/usr/bin/env bash
printf 'audit:%s\n' "$1" >> "$TEST_LOG"
EOF
cat > "$fixture/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker:%s\n' "$*" >> "$TEST_LOG"
[[ "$1" == image && "$2" == inspect && "${TEST_MISSING_IMAGE:-0}" != 1 ]]
EOF
chmod 0755 "$fixture/bin/docker" "$release_dir/tools/ops/attachment_headroom/"*.sh "$release_dir/tools/ops/attachment_audit/"*.sh "$release_dir/tools/release/rollout/"*.sh

run_resume() {
  : > "$fixture/calls"
  TEST_LOG="$fixture/calls" PATH="$fixture/bin:$PATH" \
    VOICE_PLATFORM_RELEASE_ROOT="$release_root" \
    TEST_FAIL_GUARD="${1:-0}" TEST_MISSING_IMAGE="${2:-0}" \
    bash "$script" "$sha" > "$fixture/output" 2>&1
}

run_resume
calls=()
while IFS= read -r line; do calls+=("$line"); done < "$fixture/calls"
[[ "${calls[0]}" == guard ]]
[[ "${calls[1]}" == "docker:image inspect voice-platform-api:$sha" ]]
[[ "${calls[2]}" == "docker:image inspect voice-platform-web:$sha" ]]
[[ "${calls[3]}" == "deploy:$release_dir:voice-platform-api:$sha:voice-platform-web:$sha" ]]
[[ "${calls[4]}" == "audit:$sha" ]]
[[ "${#calls[@]}" -eq 5 ]]

if run_resume 1; then
  echo 'expected guard failure to stop before image lookup and deploy' >&2
  exit 1
fi
[[ "$(cat "$fixture/calls")" == guard ]]

if run_resume 0 1; then
  echo 'expected missing image to stop before deploy' >&2
  exit 1
fi
if grep -q '^deploy:' "$fixture/calls"; then
  echo 'missing image unexpectedly reached deploy' >&2
  exit 1
fi

if TEST_LOG="$fixture/calls" PATH="$fixture/bin:$PATH" \
  VOICE_PLATFORM_RELEASE_ROOT="$release_root" bash "$script" bad-sha > "$fixture/output" 2>&1; then
  echo 'expected invalid SHA to fail' >&2
  exit 1
fi

mkdir -p "$release_dir/deploy"
mv "$release_dir/compose.yaml" "$release_dir/deploy/compose.yaml"
run_resume
calls=()
while IFS= read -r line; do calls+=("$line"); done < "$fixture/calls"
[[ "${calls[0]}" == guard ]]
[[ "${calls[1]}" == "docker:image inspect voice-platform-api:$sha" ]]
[[ "${calls[2]}" == "docker:image inspect voice-platform-web:$sha" ]]
[[ "${calls[3]}" == "deploy:$release_dir:voice-platform-api:$sha:voice-platform-web:$sha" ]]
[[ "${calls[4]}" == "audit:$sha" ]]
[[ "${#calls[@]}" -eq 5 ]]
echo 'resume-built-release tests passed'
