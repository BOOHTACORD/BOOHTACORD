"""Paired Android background voice with a verified app-only or media-only fault."""
import argparse
import json
import os
from pathlib import Path
import re
import secrets
import signal
import subprocess
import sys
import time

from .assessment import assess_fault
from .exercise import exercise


def arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--role', choices=('api', 'sfu'), required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args(argv)
    if not re.fullmatch(r'emulator-[0-9]+', args.device):
        raise ValueError('Only the dedicated QA emulator may be used')
    return args


def fresh_output(path):
    output = Path(path).resolve()
    if output.exists() and any(output.iterdir()):
        raise FileExistsError('Fault output must be new or empty')
    output.mkdir(parents=True, exist_ok=True)
    return output


def _interrupt(_signum, _frame):
    raise KeyboardInterrupt('Fault run interrupted')


def main(argv=None):
    args = arguments(argv)
    root = Path(__file__).resolve().parents[4]
    output = fresh_output(args.output)
    owner = 'qa-client-'+secrets.token_hex(8)
    command = [sys.executable, '-m',
        'tools.qa.critical_client_acceptance.issue785_android_flutter_uplink_pair',
        '--device', args.device, '--background-seconds', '120', '--output', str(output/'raw')]
    deadline = time.monotonic()+1200
    previous = signal.signal(signal.SIGTERM, _interrupt)
    try:
        with (output/'runner.log').open('w') as log:
            runner = subprocess.Popen(command, cwd=root, env=dict(os.environ, BOOHTACORD_QA_OWNER=owner),
                                      stdout=log, stderr=subprocess.STDOUT)
            try:
                timeline = exercise(runner, owner, args.role, args.device, deadline, output)
                runner.wait(timeout=max(1, deadline-time.monotonic()))
                if runner.returncode:
                    raise RuntimeError('Native background/resume checks failed; original logs retained')
                raw = json.loads((output/'raw/result.json').read_text())
                result = assess_fault(timeline, raw['receiver_media']['samples'])
                (output/'assessment.json').write_text(json.dumps(result, indent=2)+'\n')
                print(args.role, json.dumps(result), flush=True)
            finally:
                if runner.poll() is None:
                    runner.send_signal(signal.SIGINT)
                    try: runner.wait(timeout=30)
                    except subprocess.TimeoutExpired: runner.kill(); runner.wait()
    finally:
        signal.signal(signal.SIGTERM, previous)


if __name__ == '__main__':
    main()
