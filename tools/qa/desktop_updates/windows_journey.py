"""Run the actual installed app; only its real UI driver can report success."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import time
import urllib.error
import urllib.request

from tools.ci.native.process import ROOT
from .windows_process import close_owned, running_at
from .windows_stack import Stack


def wait_envelope(source, seconds):
    if not re.fullmatch('[a-f0-9]{40}', source):
        raise ValueError('Exact build source required')
    url = ('https://raw.githubusercontent.com/Egkurilov/BOOHTACORD/'
           'codex/issue337-desktop-updates/evidence/fixtures/desktop-updates/windows-' + source + '.json')
    deadline = time.monotonic() + seconds
    print('WAITING_FOR_OWNER_SIGNED_ENVELOPE source=' + source, flush=True)
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=15) as response:
                raw = response.read(65537)
            if len(raw) > 65536:
                raise ValueError('Acceptance envelope too large')
            envelope = json.loads(raw)
            value = json.loads(base64.b64decode(envelope['payload'], validate=True))
            if (value['platform'] != 'windows' or value['arch'] != 'x64' or
                    value['package_id'] != 'boohtacord_desktop' or value['native_build'] != '79' or
                    value['release_id'] != 'windows-qa337-r58' or
                    value['channel'] != 'beta' or value['distribution'] != 'direct' or
                    '/qa337-windows-1.0.44-beta-' + source + '/' not in value['download_url']):
                raise ValueError('Acceptance envelope source/identity mismatch')
            # This is a fixture input filter, not the trust decision. The shipping
            # client verifies the publisher signature and downloaded content.
            return envelope
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise RuntimeError('Could not fetch public acceptance envelope') from None
        time.sleep(10)
    raise RuntimeError('Owner-signed acceptance envelope was not supplied')


def run(source, wait_seconds):
    packages = ROOT / '.out/issue337-windows-packages'
    baseline = packages / '78'
    record = json.loads((baseline / 'qa-identity.json').read_text())
    if record['source'] != source:
        raise ValueError('Baseline source mismatch')
    installers = list(baseline.glob('*Setup.exe'))
    if len(installers) != 1:
        raise ValueError('One actual baseline installer required')
    installer = installers[0]
    with installer.open('rb') as stream:
        if hashlib.file_digest(stream, 'sha256').hexdigest() != record['files'][installer.name]['sha256']:
            raise ValueError('Baseline installer digest mismatch')
    envelope = wait_envelope(source, wait_seconds)
    root = Path(os.environ['RUNNER_TEMP']) / ('qa337-' + secrets.token_hex(8))
    stack = Stack(root)
    installed = Path(os.environ['LOCALAPPDATA']) / 'QA337 Приложение' / 'BOOHTACORD'
    executable = installed / 'current/boohtacord_desktop.exe'
    result = ROOT / '.out/issue337-windows-acceptance'
    result.mkdir(parents=True, exist_ok=False)
    owned_installation = False
    config = Path(os.environ['APPDATA']) / 'ru.boohtacord/boohtacord_desktop/issue337-acceptance-private.json'
    try:
        if installed.exists() or config.exists():
            raise RuntimeError('Refusing an existing user installation or fixture configuration')
        stack.start()
        stack.write_catalog(envelope)
        config.parent.mkdir(parents=True, exist_ok=True)
        with config.open('x') as handle:
            json.dump(stack.private_configuration(), handle)
        owned_installation = True
        subprocess.run([str(installer), '--silent', '--installto', str(installed)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
        if not executable.is_file() or not (installed / 'Update.exe').is_file():
            raise RuntimeError('Real per-user installation missing')
        process = subprocess.Popen([str(executable)], cwd=executable.parent,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        driver = root / 'driver'
        deadline = time.monotonic() + 360
        while time.monotonic() < deadline:
            failure, passed = driver / 'failure.json', driver / 'result.json'
            if failure.exists():
                raise RuntimeError('Real native application journey failed')
            if passed.exists():
                data = json.loads(passed.read_text())
                if data.get('status') != 'PASS' or data.get('installed_build') != '79':
                    raise RuntimeError('Native application result rejected')
                if process.poll() is None or not running_at(executable):
                    raise RuntimeError('Updated process was not actually relaunched')
                data['source'] = source
                data['old_process_exited'] = True
                data['new_installed_process_running'] = True
                (result / 'result.json').write_text(json.dumps(data, indent=2))
                print('PASS: actual per-user installed 78-to-79 and workspace restoration', flush=True)
                return
            time.sleep(.25)
        raise RuntimeError('Native installed update journey timed out')
    finally:
        if owned_installation and executable.exists() and running_at(executable):
            close_owned(executable)
        driver = root / 'driver'
        if driver.is_dir():
            import shutil
            for name in ('before-installed-update.png', 'after-installed-update.png',
                         'after-explicit-voice-rejoin.png', 'failure.png', 'failure.json'):
                if (driver / name).is_file():
                    shutil.copyfile(driver / name, result / name)
        if root.exists():
            stack.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True)
    parser.add_argument('--wait-seconds', type=int, default=1200)
    args = parser.parse_args()
    run(args.source, args.wait_seconds)
