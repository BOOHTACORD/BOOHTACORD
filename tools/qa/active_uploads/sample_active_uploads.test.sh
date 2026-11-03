#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fixture="$(mktemp -d /tmp/qa08-sample.XXXXXX)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin"
cat > "$fixture/bin/ssh" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
count="$(cat "$QA08_FIXTURE/count")"
count=$((count + 1))
printf '%s\n' "$count" > "$QA08_FIXTURE/count"
case "${QA08_SEQUENCE:-pass}:$count" in
  pass:2|pass:3|no-release:2|no-release:3|no-release:4) reserved=25000000 ;;
  malformed:2) reserved=invalid ;;
  failure:2) exit 1 ;;
  *) reserved=0 ;;
esac
printf 'volume=voice-platform_attachments-data\navailable_bytes=16000000000\nrequired_bytes=6343294632\nreserved_bytes=%s\napi_health=ok\n' "$reserved"
EOF
cat > "$fixture/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod 0755 "$fixture/bin/ssh" "$fixture/bin/sleep"
sha=be0c5c9fed8525915c9958b85355ce27e3250299
run() {
  printf '0\n' > "$fixture/count"
  PATH="$fixture/bin:$PATH" QA08_FIXTURE="$fixture" QA08_SAMPLE_COUNT=4 QA08_SEQUENCE="$1" \
    DEPLOY_SERVER_IP=127.0.0.1 SSH_USER=tester bash "$root/tools/qa/active_uploads/sample_active_uploads.sh" "$sha" > "$fixture/output" 2>&1
}
run pass
grep -Fq 'active_samples=2' "$fixture/output"
grep -Fq 'peak_reserved_bytes=25000000' "$fixture/output"
grep -Fq 'reservation_released=1' "$fixture/output"
for scenario in no-active no-release malformed failure; do
  if run "$scenario"; then
    printf 'expected %s to fail\n' "$scenario" >&2
    exit 1
  fi
done
if bash "$root/tools/qa/active_uploads/sample_active_uploads.sh" invalid > "$fixture/output" 2>&1; then
  printf 'expected invalid revision to fail\n' >&2
  exit 1
fi
workflow="$root/.github/workflows/qa08-active-upload.yaml"
grep -Fq 'workflow_dispatch:' "$workflow"
grep -Fq 'operator_ready:' "$workflow"
grep -Fxq "    if: github.repository == 'BOOHTACORD/BOOHTACORD' && github.ref == 'refs/heads/master'" "$workflow"
grep -Fxq '    environment: production-diagnostics' "$workflow"
grep -Fq 'tools.ops.operator.run sample' "$workflow"
if grep -Eq '^  push:|^  pull_request:' "$workflow"; then
  printf 'sampler workflow must be manual only\n' >&2
  exit 1
fi
printf 'QA-08 active-upload sampler tests passed\n'
