#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$QA12_LOG"
command=" $* "

if [[ "$1" == inspect ]]; then
  printf 'voice-platform_edge\nvoice-platform_private\n'
  exit 0
fi
[[ "$1" == compose ]] || { echo 'unexpected docker command' >&2; exit 1; }

case "$command" in
  *' up -d --wait postgres '*)
    ;;
  *' maintenance-admission --enable '*)
    printf 'on\n' > "$QA12_STATE/maintenance"
    ;;
  *' maintenance-admission --disable '*)
    printf 'off\n' > "$QA12_STATE/maintenance"
    ;;
  *' run --rm --no-deps migrate '*)
    [[ "$(cat "$QA12_STATE/maintenance")" == on ]]
    ;;
  *' run --rm --no-deps screen-preview-storage-init '*)
    [[ "$(cat "$QA12_STATE/maintenance")" == on ]]
    ;;
  *' up -d --wait egress '*)
    [[ "$(cat "$QA12_STATE/maintenance")" == on ]]
    ;;
  *' up -d --no-deps --no-build api web '*)
    [[ "$(cat "$QA12_STATE/maintenance")" == on ]]
    sed -n 's/^API_IMAGE=//p' "$QA12_PROJECT/.env" > "$QA12_STATE/running-api"
    sed -n 's/^WEB_IMAGE=//p' "$QA12_PROJECT/.env" > "$QA12_STATE/running-web"
    ;;
  *' up -d --no-deps --no-build --force-recreate proxy '*)
    if [[ "${QA12_FAIL_PROXY_ONCE:-0}" == 1 && ! -e "$QA12_STATE/proxy-failed" ]]; then
      : > "$QA12_STATE/proxy-failed"
      exit 47
    fi
    ;;
  *' ps -q proxy '*)
    printf 'qa12-proxy\n'
    ;;
  *' pull api migrate web '*|*' exec -T proxy caddy validate '*)
    ;;
  *)
    echo "unexpected compose command: $*" >&2
    exit 1
    ;;
esac
