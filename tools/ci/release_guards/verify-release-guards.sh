#!/usr/bin/env bash
set -euo pipefail

python3 -m venv .out/release-guards-venv
source .out/release-guards-venv/bin/activate
python -m pip install -r tools/requirements-ci.txt -r tools/verify/openapi_parity/requirements.txt

bash tools/ci/powershell/install-ci-powershell.sh
compose_cli="$(bash tools/ci/compose/install-ci-compose.sh)"
trap 'rm -f "$compose_cli"' EXIT
export VOICE_PLATFORM_COMPOSE_CLI="$compose_cli"
pwsh -NoProfile -File tools/verify/contracts/verify-contracts.ps1
pwsh -NoProfile -File tools/verify/spec_traceability/verify-spec-traceability.ps1
pwsh -NoProfile -File tools/verify/ci_sbom/verify-ci-sbom.ps1
pwsh -NoProfile -File tools/verify/github_workflows/verify-github-workflows.ps1
pwsh -NoProfile -File tools/verify/android_release_signing/verify-android-release-signing.ps1
printf 'Checking Compose configuration...\n'
"$compose_cli" --env-file .env.example -f deploy/compose.yaml --profile operator config --quiet
pwsh -NoProfile -File tools/verify/otel_egress/verify-otel-egress.ps1
python3 -m unittest tools.verify.trace_dashboard.test_traces_dashboard
printf 'Checking Compose image contract...\n'
pwsh -NoProfile -File tools/verify/compose_images/verify-compose-images.ps1
bash tools/ci/release_guards/test-negative-boundaries.sh
