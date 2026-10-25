"""Execute platform-only vendor regressions on an actual Apple host."""
import json
import subprocess
import sys
from tools.ci.native.process import ROOT
from tools.ci.flutter_setup.vendor_locks import prepare
from .events import validate


def main():
    destination = ROOT / '.out/checks/macos-unit'
    destination.mkdir(parents=True, exist_ok=False)
    report = {'status': 'BLOCKED', 'platform': sys.platform, 'tests': 0, 'physical_media': 'NOT_RUN'}
    path = destination / 'result.json'
    path.write_text(json.dumps(report) + '\n')
    try:
        if sys.platform != 'darwin': raise RuntimeError('macOS unit route requires an Apple host')
        report['status'] = 'FAIL'
        prepare(ROOT, 'livekit_client')
        package = ROOT / 'clients/flutter/packages/livekit_client'
        subprocess.run(['flutter', 'pub', 'get', '--enforce-lockfile'], cwd=package, check=True)
        log = destination / 'screen-capture-engine.jsonl'
        with log.open('w', encoding='utf-8') as stream:
            subprocess.run(['flutter', 'test', '--no-pub', '--machine', 'test/options/screen_capture_engine_test.dart'],
                           cwd=package, stdout=stream, check=True)
        count = validate([json.loads(line) for line in log.read_text(encoding='utf-8').splitlines()])
        report.update(status='PASS', tests=count, skipped=0)
    finally:
        path.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__': main()
