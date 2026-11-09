"""Reject first-party SSE implementations; permit named baseline/negative fixtures."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ROOTS = ('backend/internal', 'backend/cmd', 'clients/web/src', 'clients/web/artifacts',
         'clients/web/public', 'clients/web/scripts', 'clients/flutter/lib', 'clients/flutter/native',
         'clients/flutter/android/app/src', 'clients/flutter/ios/Runner',
         'clients/flutter/ios/ScreenShareExtension', 'clients/flutter/macos/Runner',
         'clients/flutter/windows/runner', 'contracts', 'deploy', 'tools')
EXTENSIONS = {'.go', '.dart', '.ts', '.tsx', '.mts', '.vue', '.js', '.jsx', '.mjs', '.cjs',
              '.py', '.ps1', '.sh', '.yaml', '.yml', '.json', '.html', '.kt', '.java',
              '.swift', '.m', '.mm', '.h', '.c', '.cc', '.cpp'}
EXCEPTIONS = {
    'backend/internal/load/roster_matrix/open_legacy.go',  # owned baseline comparison only
    'tools/verify/contracts/voice.ps1',  # negative contract assertions
    'tools/verify/realtime_migration/guard.py',  # the patterns below
}
# This exact line rejects legacy requests during a real-stack test; no other
# line in that scenario is exempt from the migration scan.
NEGATIVE_ASSERTIONS = {
    ('tools/qa/voice_roster_multiclient/scenario.cjs',
     "client.requests.some(path => ['/api/v1/voice/rosters/events', '/api/v1/maintenance/events'].includes(path))) throw Error('legacy or duplicate stream')"),
}
PATTERNS = tuple(re.compile(value, re.IGNORECASE) for value in (
    r'\bEventSource\b', r'text/event-stream', r'Last-Event-ID',
    r'server[- .]sent[- .]events', r'\bwriteSSEHeaders\s*\(', r'\bnewRosterWriter\s*\(',
    r'/voice/rosters/events', r'/maintenance/events',
    r'\bmaintenanceEvents\s*\(', r'\bvoiceRosterEvents\s*\(',
))


def test_file(path):
    name = path.name
    return (name.startswith('test_') or name.endswith(('_test.go', '_test.dart', '.spec.ts', '.test.ts', '.spec.mjs', '.test.mjs'))
            or 'test' in path.parts or 'tests' in path.parts)


def scan(root, require_roots=False):
    root = Path(root)
    findings = []
    for item in ROOTS:
        directory = root / item
        if not directory.exists():
            if require_roots: raise ValueError('Missing required source root: ' + item)
            continue
        for path in directory.rglob('*'):
            relative = path.relative_to(root).as_posix()
            if not path.is_file() or path.suffix not in EXTENSIONS or relative in EXCEPTIONS or test_file(path):
                continue
            for number, line in enumerate(path.read_text(encoding='utf8').splitlines(), 1):
                if (relative, line.strip()) in NEGATIVE_ASSERTIONS:
                    continue
                if any(pattern.search(line) for pattern in PATTERNS):
                    findings.append((relative, number))
    return sorted(set(findings))


def main():
    findings = scan(ROOT, require_roots=True)
    for path, line in findings: print(f'{path}:{line}')
    print(f'Realtime migration guard: {len(findings)} active findings')
    return 1 if findings else 0


if __name__ == '__main__':
    raise SystemExit(main())
