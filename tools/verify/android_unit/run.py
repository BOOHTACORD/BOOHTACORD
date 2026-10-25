"""Run every reviewed plugin unit test task in one real Android Kotlin mode."""
import argparse
import json
import os
import subprocess
from tools.ci.native.process import ROOT
from .inventory import EXPECTED, verify_sources
from .results import validate


def execute(mode):
    if mode not in ('legacy', 'builtin'): raise ValueError('Unknown Kotlin mode')
    destination = ROOT / '.out/checks/android-unit' / mode
    destination.mkdir(parents=True, exist_ok=False)
    report = {'mode': mode, 'status': 'FAIL', 'classes': {}}
    path = destination / 'result.json'
    path.write_text(json.dumps(report) + '\n')
    try:
        verify_sources(ROOT)
        wrapper = ROOT / 'clients/flutter/android' / ('gradlew.bat' if os.name == 'nt' else 'gradlew')
        command = [str(wrapper),
                   *(':' + plugin + ':testDebugUnitTest' for plugin in EXPECTED),
                   '--no-daemon', '--rerun-tasks', '-I', str(ROOT / 'tools/verify/android_unit/reports.gradle')]
        command += ['-Pandroid.builtInKotlin=' + ('true' if mode == 'builtin' else 'false')]
        if mode == 'builtin':
            command += ['-I', str(ROOT / 'tools/verify/android_kotlin/verify_built_in.gradle')]
        environment = dict(os.environ, BOOHTACORD_JUNIT_DIR=str(destination))
        subprocess.run(command, cwd=ROOT / 'clients/flutter/android', env=environment, check=True)
        for plugin, expected in EXPECTED.items():
            report['classes'][plugin] = validate(destination / plugin, expected)
        report.update(status='PASS', tests=sum(sum(row.values()) for row in report['classes'].values()))
    finally:
        path.write_text(json.dumps(report, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('legacy', 'builtin'))
    print(json.dumps(execute(parser.parse_args().mode)))


if __name__ == '__main__': main()
