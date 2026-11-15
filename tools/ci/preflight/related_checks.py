"""Run bounded project-owned contract/traceability checks when applicable."""
import os
from pathlib import Path

from tools.ci.preflight.generated import check

CONTRACTS = ['pwsh', '-NoProfile', '-File', 'tools/verify/contracts/verify-contracts.ps1']
TRACEABILITY = ['pwsh', '-NoProfile', '-File', 'tools/verify/spec_traceability/verify-spec-traceability.ps1']


def approved_brief():
    path = os.environ.get('VOICE_PLATFORM_APPROVED_SPEC_PATH', r'C:\Users\egkur\Downloads\TZ_Voice_Platform_v1.0.md')
    return Path(path).is_file()


def checks(root, paths):
    result = {name: {'status': 'N/A', 'command': command, 'reason': 'Not applicable to this diff.'}
              for name, command in [('contracts', CONTRACTS), ('traceability', TRACEABILITY)]}
    if any(path.startswith('contracts/') for path in paths):
        result['contracts'] = check(root, CONTRACTS, timeout=45)
    if any(path.startswith('backlog/') for path in paths):
        result['traceability'] = (check(root, TRACEABILITY, timeout=45) if approved_brief() else
                                  {'status': 'BLOCKED', 'command': TRACEABILITY,
                                   'reason': 'Approved brief unavailable; set VOICE_PLATFORM_APPROVED_SPEC_PATH.'})
    return result
