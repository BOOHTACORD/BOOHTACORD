#!/usr/bin/env bash
# Both protected callers use the same current controller and bounded transport.
set -euo pipefail
exec python3 -m tools.release.delivery.transfer
