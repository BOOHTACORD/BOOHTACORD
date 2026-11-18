"""Run the Issue 785 Android Chrome paired-media resume acceptance."""

import argparse
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from tools.qa.critical_client_acceptance.stack import Stack
from tools.qa.local_features.native import verify_device


PAIR_FILE = Path('/private/tmp/issue785-browser-pair.json')
ORIGIN = 'https://localhost:4810'


def adb(device, *args, check=True):
    return subprocess.run(
        ['adb', '-s', device, *args],
        check=check,
        capture_output=True,
        text=True,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[3]
    verify_device('android', args.device)
    if adb(args.device, 'shell', 'getprop', 'sys.boot_completed').stdout.strip() != '1':
        raise RuntimeError('Android QA emulator is not fully booted')

    reverse_ports = (4810, 4881)
    existing_reverse = adb(args.device, 'reverse', '--list').stdout.split()
    if any(f'tcp:{port}' in existing_reverse for port in reverse_ports):
        raise ValueError('An existing QA reverse belongs to another run')
    if any('tcp:9222' in row for row in adb(args.device, 'forward', '--list').stdout.splitlines()):
        raise ValueError('An existing Chrome DevTools forward belongs to another run')
    if PAIR_FILE.exists():
        raise FileExistsError('An existing private Issue 785 pair input belongs to another run')

    root_out = root / '.out'
    root_out.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='issue785-paired-', dir=root_out))
    stack = Stack(root, work)
    created_reverse = []
    forward_created = False
    pair_created = False

    try:
        os.environ.update({
            'DOCKER_CONTEXT': 'colima-boohtacord-qa',
            'BOOHTACORD_QA_EGRESS_PLATFORM': 'linux/amd64',
            'VITE_PUBLIC_ORIGIN': ORIGIN,
            'QA_ORIGIN': ORIGIN,
            'QA_DB_OWNER': stack.owner,
        })

        for port in reverse_ports:
            adb(args.device, 'reverse', f'tcp:{port}', f'tcp:{port}')
            created_reverse.append(port)
        adb(args.device, 'forward', 'tcp:9222', 'localabstract:chrome_devtools_remote')
        forward_created = True
        adb(args.device, 'shell', 'am', 'start', '-n',
            'com.android.chrome/com.google.android.apps.chrome.Main')

        stack.start()
        with PAIR_FILE.open('x', encoding='utf8') as pair_input:
            pair_created = True
            pair_input.write(json.dumps({'origin': ORIGIN, 'password': stack.password}))
        PAIR_FILE.chmod(0o600)

        script = Path(__file__).with_name('issue785_android_chrome_pair.mjs')
        subprocess.run(['node', str(script)], cwd=root, env=os.environ.copy(), check=True)
    finally:
        try:
            stack.close()
        finally:
            try:
                if pair_created:
                    PAIR_FILE.unlink(missing_ok=True)
            finally:
                try:
                    for port in reversed(created_reverse):
                        adb(args.device, 'reverse', '--remove', f'tcp:{port}', check=False)
                finally:
                    try:
                        if forward_created:
                            adb(args.device, 'forward', '--remove', 'tcp:9222', check=False)
                    finally:
                        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    main()
