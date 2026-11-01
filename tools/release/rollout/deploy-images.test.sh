#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
script="$repository_root/tools/release/rollout/deploy-images.sh"
temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT

project_dir="$temporary_root/project"
bin_dir="$temporary_root/bin"
mkdir -p "$project_dir/scripts" "$bin_dir"
mkdir -p "$project_dir/tools/ops/attachment_headroom"
printf '#!/usr/bin/env bash\nexit 0\n' > "$project_dir/tools/ops/attachment_headroom/check-attachment-volume-headroom.sh"
printf 'services: {}\n' > "$project_dir/compose.yaml"
cat > "$project_dir/.env" <<'EOF'
PUBLIC_HOST=v.bootybay.ru
API_IMAGE=ghcr.io/example/voice-platform-api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
WEB_IMAGE=ghcr.io/example/voice-platform-web@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
EOF

cat > "$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"

if [[ "$1" == "compose" && " $* " == *" up -d --wait postgres "* && "${FAKE_POSTGRES_MODE:-allowed}" == "detached" && ! -f "$FAKE_POSTGRES_FAILED" ]]; then
  touch "$FAKE_POSTGRES_FAILED"
  printf '%s\n' 'Error response from daemon: container postgres-id is not connected to the network voice-platform_private' >&2
  exit 1
fi

if [[ "$1" == "compose" && " $* " == *" run --rm --no-deps screen-preview-storage-init "* && "${FAKE_PREVIEW_INIT_MODE:-allowed}" == "fail" ]]; then
  printf '%s\n' 'screen preview storage initialization failed' >&2
  exit 1
fi

if [[ "$1" == "compose" && " $* " == *" up -d --wait egress "* && "${FAKE_EGRESS_MODE:-allowed}" == "fail" ]]; then
  printf '%s\n' 'screen preview Egress failed to start' >&2
  exit 1
fi

if [[ "$1" == "inspect" ]]; then
  [[ "${FAKE_NETWORK_MODE:-allowed}" != "extra" ]] || printf '%s\n' fluxer_fluxer
  printf '%s\n' voice-platform_edge voice-platform_private ''
  exit 0
fi

[[ "$1" == "compose" && " $* " == *" maintenance-admission --disable "* && "${FAKE_DISABLE_MODE:-allowed}" == "fail" ]] && exit 1

if [[ "$1" == "compose" && " $* " == *" ps -q proxy "* ]]; then
  printf '%s\n' proxy-container
fi
EOF
chmod 0755 "$bin_dir/docker"

cat > "$bin_dir/python3" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'python3 %s\n' "$*" >> "$FAKE_DOCKER_LOG"
EOF
chmod 0755 "$bin_dir/python3"

cat > "$bin_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "curl $*" >> "$FAKE_DOCKER_LOG"
[[ "${FAKE_HEALTH_MODE:-allowed}" != "fail" ]]
EOF
chmod 0755 "$bin_dir/curl"

cat > "$bin_dir/sleep" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "sleep $*" >> "$FAKE_DOCKER_LOG"
EOF
chmod 0755 "$bin_dir/sleep"

run_deploy() {
  local network_mode="$1"
  local output="$2"
  : > "$temporary_root/phases-$network_mode.txt"
  FAKE_DOCKER_LOG="$temporary_root/commands-$network_mode.log" \
  FAKE_NETWORK_MODE="$network_mode" \
  FAKE_POSTGRES_MODE="${5:-allowed}" \
  FAKE_PREVIEW_INIT_MODE="${6:-allowed}" \
  FAKE_EGRESS_MODE="${7:-allowed}" \
  FAKE_POSTGRES_FAILED="$temporary_root/postgres-failed-$network_mode" \
  FAKE_HEALTH_MODE="${3:-allowed}" \
  FAKE_DISABLE_MODE="${4:-allowed}" \
  PATH="$bin_dir:$PATH" \
  VOICE_PLATFORM_DIR="$project_dir" \
  VOICE_PLATFORM_DELIVERY_PHASES="$temporary_root/phases-$network_mode.txt" \
  API_IMAGE="ghcr.io/example/voice-platform-api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
  WEB_IMAGE="ghcr.io/example/voice-platform-web@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" \
  bash "$script" > "$output" 2>&1 || { cat "$output" >&2; return 1; }
}

line_number() { grep -n -F "$1" "$2" | head -n 1 | cut -d: -f1; }

helper_guard_line="$(grep -n -F '[[ -r "$livekit_private_path_script" ]]' "$script" | cut -d: -f1)"
admission_enable_line="$(grep -n -F '[[ "$admission_enabled" -eq 1 ]] || enable_maintenance_admission' "$script" | cut -d: -f1)"
[[ "$helper_guard_line" -lt "$admission_enable_line" ]]

allowed_output="$temporary_root/allowed.out"
run_deploy allowed "$allowed_output"
allowed_log="$temporary_root/commands-allowed.log"
python3 - "$temporary_root/phases-allowed.txt" <<'PY_TIMINGS'
from pathlib import Path
import sys
from tools.release.install.timings import parse
value = parse(Path(sys.argv[1]).read_text())
assert value['status'] == 'PASS'
assert len(value['events']) == 10
assert value['durations']['maintenance_request_to_disable_seconds'] >= value['durations']['maintenance_seconds']
PY_TIMINGS


database_line="$(line_number 'up -d --wait postgres' "$allowed_log")"
enable_line="$(line_number 'maintenance-admission --enable' "$allowed_log")"
livekit_path_line="$(line_number 'livekit_private_path.py' "$allowed_log")"
wait_line="$(line_number 'sleep 15' "$allowed_log")"
pull_line="$(line_number 'pull api migrate web' "$allowed_log")"
migration_database_line="$(grep -n -F 'up -d --wait postgres' "$allowed_log" | sed -n '2p' | cut -d: -f1)"
migrate_line="$(line_number 'run --rm --no-deps migrate' "$allowed_log")"
preview_init_line="$(line_number 'run --rm --no-deps screen-preview-storage-init' "$allowed_log")"
egress_line="$(line_number 'up -d --wait egress' "$allowed_log")"
workload_line="$(line_number 'up -d --no-deps --no-build api web' "$allowed_log")"
proxy_line="$(line_number 'up -d --no-deps --no-build --force-recreate proxy' "$allowed_log")"
inspect_line="$(line_number 'inspect --format' "$allowed_log")"
validate_line="$(line_number 'exec -T proxy caddy validate' "$allowed_log")"
health_line="$(line_number 'curl -fsS --retry 5 --retry-connrefused https://v.bootybay.ru/api/v1/health' "$allowed_log")"
disable_line="$(line_number 'maintenance-admission --disable' "$allowed_log")"

[[ "$database_line" -lt "$enable_line" ]]
[[ "$enable_line" -lt "$wait_line" ]]
[[ "$enable_line" -lt "$livekit_path_line" ]]
[[ "$livekit_path_line" -lt "$wait_line" ]]
[[ "$wait_line" -lt "$pull_line" ]]
[[ "$pull_line" -lt "$migrate_line" ]]
[[ "$pull_line" -lt "$migration_database_line" ]]
[[ "$migration_database_line" -lt "$migrate_line" ]]
[[ "$migrate_line" -lt "$workload_line" ]]
[[ "$migrate_line" -lt "$preview_init_line" ]]
[[ "$preview_init_line" -lt "$workload_line" ]]
[[ "$preview_init_line" -lt "$egress_line" ]]
[[ "$egress_line" -lt "$workload_line" ]]
[[ "$workload_line" -lt "$proxy_line" ]]
[[ "$proxy_line" -lt "$inspect_line" ]]
[[ "$inspect_line" -lt "$validate_line" ]]
[[ "$validate_line" -lt "$health_line" ]]
[[ "$health_line" -lt "$disable_line" ]]
[[ "$(grep -Fc 'up -d --wait postgres' "$allowed_log")" == 3 ]]
[[ "$(grep -Fc 'run --rm --no-deps screen-preview-storage-init' "$allowed_log")" == 1 ]]
[[ "$(grep -Fc 'up -d --wait egress' "$allowed_log")" == 1 ]]
extra_output="$temporary_root/extra.out"
! run_deploy extra "$extra_output" || { echo 'expected extra proxy network to fail deployment' >&2; exit 1; }
grep -F 'Proxy has an unexpected Docker network attachment.' "$extra_output"
! grep -q '^rollout_completed ' "$temporary_root/phases-extra.txt"
extra_log="$temporary_root/commands-extra.log"
if grep -Fq 'exec -T proxy caddy validate' "$extra_log"; then exit 1; fi
if grep -Fq 'curl -fsS --retry 5 --retry-connrefused https://v.bootybay.ru/api/v1/health' "$extra_log"; then exit 1; fi
grep -Fq 'maintenance-admission --disable' "$extra_log"

network_repair_output="$temporary_root/network-repair.out"
run_deploy repair "$network_repair_output" allowed allowed detached
network_repair_log="$temporary_root/commands-repair.log"
grep -Fq 'align-existing-private-network.py' "$network_repair_log"
grep -Fq '.compose.recovery.' "$network_repair_log"
[[ "$(grep -Fc 'up -d --wait postgres' "$network_repair_log")" == 4 ]]

health_output="$temporary_root/health.out"
! run_deploy allowed "$health_output" fail || { echo 'expected health failure to fail deployment' >&2; exit 1; }
health_log="$temporary_root/commands-allowed.log"
grep -Fq 'maintenance-admission --enable' "$health_log"
grep -Fq 'maintenance-admission --disable' "$health_log"

disable_output="$temporary_root/disable.out"
! run_deploy allowed "$disable_output" allowed fail || { echo 'expected maintenance disable failure to fail deployment' >&2; exit 1; }
grep -F 'Could not disable maintenance admission after a failed deployment.' "$disable_output"

preview_init_output="$temporary_root/preview-init-failed.out"
! run_deploy preview-init-fail "$preview_init_output" allowed allowed allowed fail || { echo 'expected preview storage initialization failure to fail deployment' >&2; exit 1; }
preview_init_log="$temporary_root/commands-preview-init-fail.log"
grep -Fq 'run --rm --no-deps screen-preview-storage-init' "$preview_init_log"
if grep -Fq 'up -d --no-deps --no-build api web' "$preview_init_log"; then exit 1; fi
grep -Fq 'maintenance-admission --disable' "$preview_init_log"

egress_output="$temporary_root/egress-failed.out"
! run_deploy egress-fail "$egress_output" allowed allowed allowed allowed fail || { echo 'expected Egress startup failure to fail deployment' >&2; exit 1; }
egress_failed_log="$temporary_root/commands-egress-fail.log"
grep -Fq 'up -d --wait egress' "$egress_failed_log"
if grep -Fq 'up -d --no-deps --no-build api web' "$egress_failed_log"; then exit 1; fi
grep -Fq 'maintenance-admission --disable' "$egress_failed_log"

echo 'deploy-images tests passed'
