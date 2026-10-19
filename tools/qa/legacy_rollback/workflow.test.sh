#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
workflow="$root/.github/workflows/rehearse-compatible-rollback.yaml"
[[ -r "$workflow" ]]
grep -Fq 'workflow_dispatch:' "$workflow"
grep -Fq 'current_sha:' "$workflow"
grep -Fq 'previous_sha:' "$workflow"
grep -Fq 'observers_confirmed:' "$workflow"
grep -Fq 'group: v-bootybay-production' "$workflow"
grep -Fq 'cancel-in-progress: false' "$workflow"
grep -Fxq "    if: github.repository == 'Egkurilov/BOOHTACORD' && github.ref == 'refs/heads/master'" "$workflow"
grep -Fxq '    environment: production' "$workflow"
grep -Fq 'bash tools/release/ssh/configure-deploy-ssh.sh' "$workflow"
grep -Fq 'bash tools/release/delivery/rollback.sh' "$workflow"
grep -Fq 'StrictHostKeyChecking=yes' "$root/tools/release/delivery/rollback.sh"
if grep -Eq '^  push:|^  pull_request:' "$workflow"; then exit 1; fi
echo 'QA-12 manual workflow source contract passed'
