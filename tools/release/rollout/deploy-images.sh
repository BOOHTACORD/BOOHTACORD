#!/usr/bin/env bash
set -euo pipefail

project_dir="${VOICE_PLATFORM_DIR:-/opt/voice-platform}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
compose_dir="$project_dir"
[[ ! -f "$project_dir/deploy/compose.yaml" ]] || compose_dir="$project_dir/deploy"
compose_file="$compose_dir/compose.yaml"
env_file="$project_dir/.env"

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

# The current installer supplies a private owned file. Old retained runtimes
# ignore this input and are reported explicitly as unmeasured legacy releases.
delivery_phase() {
  if [[ -n "${VOICE_PLATFORM_DELIVERY_PHASES:-}" ]]; then
    [[ -f "$VOICE_PLATFORM_DELIVERY_PHASES" && ! -L "$VOICE_PLATFORM_DELIVERY_PHASES" ]] || fail "Delivery phase sink is unavailable."
    printf '%s %s\n' "$1" "$(date +%s)" >> "$VOICE_PLATFORM_DELIVERY_PHASES"
  fi
}

livekit_private_path_script="$script_dir/livekit_private_path.py"
[[ -r "$livekit_private_path_script" ]] || fail "LiveKit private path preflight is missing from the release."

api_image="${API_IMAGE:-}"
web_image="${WEB_IMAGE:-}"
[[ -n "$api_image" ]] || fail "API_IMAGE is required."
[[ -n "$web_image" ]] || fail "WEB_IMAGE is required."

if [[ "$api_image" =~ ^voice-platform-api:([0-9a-f]{40})$ ]]; then
  api_revision="${BASH_REMATCH[1]}"
  [[ "$web_image" =~ ^voice-platform-web:([0-9a-f]{40})$ ]] || fail "Images must be matching local commit tags or registry digest references without latest."
  web_revision="${BASH_REMATCH[1]}"
  [[ "$api_revision" == "$web_revision" ]] || fail "Local API and web images must use the same commit revision."
  release_mode="local-build"
elif [[ "$api_image" =~ ^voice-platform-api@sha256:[0-9a-f]{64}$ && "$web_image" =~ ^voice-platform-web@sha256:[0-9a-f]{64}$ ]]; then
  release_mode="local-build"
elif [[ "$api_image" == */* && "$api_image" == *@sha256:* && "$web_image" == */* && "$web_image" == *@sha256:* && "$api_image" != *:latest@* && "$web_image" != *:latest@* ]]; then
  release_mode="registry-digest"
else
  fail "Images must be matching local commit tags or registry digest references without latest."
fi
[[ -r "$env_file" ]] || fail "Deployment environment file is unavailable."
public_host="$(sed -n 's/^PUBLIC_HOST=//p' "$env_file" | tail -n 1)"
[[ "$public_host" =~ ^[A-Za-z0-9.-]+$ ]] || fail "PUBLIC_HOST must be a hostname."

compose=(docker compose --project-directory "$compose_dir" --env-file "$env_file" -f "$compose_file")

if [[ "$release_mode" == "local-build" ]]; then
  docker image inspect "$api_image" >/dev/null || fail "Local API image is unavailable."
  docker image inspect "$web_image" >/dev/null || fail "Local web image is unavailable."
fi

admission_enabled=0
temporary_env=''
temporary_compose=''

disable_maintenance_admission() {
  if ! "${compose[@]}" up -d --wait postgres; then
    return 1
  fi
  if ! "${compose[@]}" --profile operator run --rm --no-deps maintenance-admission --disable; then
    return 1
  fi
  admission_enabled=0
  delivery_phase maintenance_disabled
}

enable_maintenance_admission() {
  delivery_phase maintenance_requested
  if ! "${compose[@]}" --profile operator run --rm --no-deps maintenance-admission --enable; then
    if [[ -n "$temporary_compose" ]]; then
      python3 "$script_dir/reconcile-postgres-credential.py" "$project_dir" "$temporary_compose"
    else
      python3 "$script_dir/reconcile-postgres-credential.py" "$project_dir"
    fi
    "${compose[@]}" --profile operator run --rm --no-deps maintenance-admission --enable
  fi
  admission_enabled=1
  delivery_phase maintenance_enabled
}

cleanup() {
  local status=$?
  [[ -z "$temporary_env" ]] || rm -f "$temporary_env"
  [[ -z "$temporary_compose" ]] || rm -f "$temporary_compose"
  if [[ "$admission_enabled" -eq 1 ]] && ! disable_maintenance_admission; then
    printf '%s\n' "Could not disable maintenance admission after a failed deployment." >&2
    status=1
  fi
  trap - EXIT
  exit "$status"
}
trap cleanup EXIT

delivery_phase rollout_started
postgres_output=''
if ! postgres_output="$("${compose[@]}" up -d --wait postgres 2>&1)"; then
  printf '%s\n' "$postgres_output" >&2
  if [[ "$postgres_output" != *"has active endpoints"* && "$postgres_output" != *"not connected to the network"* ]]; then
    fail "PostgreSQL service could not be started; deployment containers were not removed."
  fi
  temporary_compose="$(mktemp "$project_dir/.compose.recovery.XXXXXX")"
  python3 "$script_dir/align-existing-private-network.py" "$project_dir" /opt/voice-platform/.env "$temporary_compose"
  compose=(docker compose --project-directory "$compose_dir" --env-file "$env_file" -f "$temporary_compose")
  "${compose[@]}" up -d --wait postgres
else
  printf '%s\n' "$postgres_output"
fi
python3 "$script_dir/align-existing-private-network.py" "$project_dir" --ensure-postgres-alias
[[ "$admission_enabled" -eq 1 ]] || enable_maintenance_admission
python3 "$livekit_private_path_script" "$project_dir"
sleep 15
if [[ "$release_mode" == "registry-digest" ]]; then
  API_IMAGE="$api_image" WEB_IMAGE="$web_image" "${compose[@]}" pull api migrate web
fi
bash "$project_dir/tools/ops/attachment_headroom/check-attachment-volume-headroom.sh"

umask 077
temporary_env="$(mktemp "$env_file.release.XXXXXX")"
awk '!/^(API_IMAGE|WEB_IMAGE)=/' "$env_file" > "$temporary_env"
printf 'API_IMAGE=%s\nWEB_IMAGE=%s\n' "$api_image" "$web_image" >> "$temporary_env"
install -m 600 "$temporary_env" "$env_file"
rm -f "$temporary_env"
temporary_env=''

"${compose[@]}" up -d --wait postgres
delivery_phase migration_started
"${compose[@]}" run --rm --no-deps migrate
delivery_phase migration_completed
"${compose[@]}" run --rm --no-deps screen-preview-storage-init
# Server-managed screen previews require the LiveKit Egress worker and its
# Redis/LiveKit dependencies. Keep this in the deployment path so API health
# cannot pass while preview capture is silently unavailable.
"${compose[@]}" up -d --wait egress
delivery_phase services_started
"${compose[@]}" up -d --no-deps --no-build api web
"${compose[@]}" up -d --no-deps --no-build --force-recreate proxy
bash "$script_dir/assert-proxy-networks.sh" "$project_dir"
"${compose[@]}" exec -T proxy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
delivery_phase health_started
curl -fsS --retry 5 --retry-connrefused "https://${public_host}/api/v1/health"
delivery_phase health_passed
disable_maintenance_admission
delivery_phase rollout_completed
