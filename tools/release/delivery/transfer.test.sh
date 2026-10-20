#!/usr/bin/env bash
# Owned fixtures only. No network, production credentials or remote mutation.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$root"
python3 -m unittest tools.release.delivery.test_transfer tools.release.delivery.test_commands tools.release.delivery.test_phases tools.release.delivery.test_payload tools.release.delivery.test_readback_contract tools.release.install.test_invocation
