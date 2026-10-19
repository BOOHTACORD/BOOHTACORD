#!/usr/bin/env bash
# Controlled local fixtures only: no production SSH, signing or deployment.
set -euo pipefail
if (( BASH_VERSINFO[0] < 4 )); then
  printf 'Release boundary fixtures require Bash 4+ (Linux CI); system Bash 3 is unsupported.\n' >&2
  exit 2
fi
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$root"
bash tools/ops/attachment_headroom/check-attachment-volume-headroom.test.sh
bash tools/ops/attachment_audit/audit-attachment-volume.test.sh
bash tools/qa/active_uploads/sample_active_uploads.test.sh
bash tools/release/preflight/preflight.test.sh
python3 tools/verify/oci/test_verify_oci.py
bash tools/verify/running_images/verify_running.test.sh
bash tools/release/rollout/deploy-images.test.sh
bash tools/release/rollout/deploy-images-volume-guard.test.sh
bash tools/release/rollout/deploy-images-rollback.test.sh
bash tools/qa/legacy_rollback/image_ref.test.sh
bash tools/qa/legacy_rollback/preflight.test.sh
bash tools/qa/legacy_rollback/rehearse.test.sh
bash tools/qa/legacy_rollback/workflow.test.sh
bash tools/release/legacy_install/deploy-local-images.test.sh
bash tools/release/delivery/transfer.test.sh
bash tools/release/legacy_resume/resume.test.sh
bash tools/ops/docker_storage/reclaim_old_images.test.sh
bash tools/ops/docker_storage/prune_build_cache.test.sh
bash tools/ops/docker_storage/reclaim_deploy_headroom.test.sh
