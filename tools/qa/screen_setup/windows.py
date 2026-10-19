"""Release Windows GUI layout and Escape acceptance on an owned native API/SFU fixture."""
import base64
import hashlib
import json
import os
import re
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import time

from tools.ci.native.process import ROOT, output, require_version
from tools.qa.desktop_updates.windows_process import close_owned, running_at
from tools.qa.desktop_updates.windows_stack import Stack


def validate_result(value):
    expected = {a + '-' + b for a in ('header', 'dock') for b in ('initial', 'traversed')}
    rows = value.get('cases', [])
    flags = ('escape', 'focus_returned', 'same_connected_room_and_lease',
             'mute_deafen_preserved', 'no_publication', 'footer_visible')
    if (value.get('status') != 'PASS' or
            value.get('input') != 'Win32 SendInput with exact foreground PID guard' or
            len(rows) != 4 or {row.get('case') for row in rows} != expected or
            any(row.get(flag) is not True for row in rows for flag in flags) or
            any(row.get(flag) is not True for row in rows
                if row.get('case', '').endswith('-traversed')
                for flag in ('quality_reachable', 'cancel_keyboard_reachable'))):
        raise ValueError('Incomplete Windows GUI layout and Escape acceptance')


def retain_failure(driver, destination):
    value = json.loads((driver / 'failure.json').read_text(encoding='utf-8'))
    # Keep only controlled fixture codes, never app/configuration/log contents.
    result = {'status': 'FAIL'}
    for name in ('step', 'reason'):
        code = value.get(name)
        if not isinstance(code, str) or not re.fullmatch(r'[a-z_]{1,64}', code):
            raise ValueError('Unsafe Windows GUI failure code')
        result[name] = code
    (destination / 'failure.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    image = driver / 'failure.png'
    if image.exists():
        if image.stat().st_size > 2_000_000:
            raise ValueError('Synthetic failure capture exceeds evidence bound')
        raw = image.read_bytes()
        if not raw.startswith(b'\x89PNG\r\n\x1a\n'):
            raise ValueError('Synthetic failure capture is not PNG')
        (destination / 'failure.png').write_bytes(raw)
    return result


def main():
    if sys.platform != 'win32':
        raise RuntimeError('Actual Windows GUI host required')
    if (os.environ.get('GITHUB_ACTIONS') != 'true' or
            os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted'):
        raise RuntimeError('Disposable hosted Windows CI runner required')
    from tools.ci.windows_gates.transfer import verify_workspace, read, RELEASE
    binding = verify_workspace()
    release = ROOT / RELEASE
    manifest = read(release / 'artifact-manifest.json')
    versions = manifest['toolchains']
    require_version('flutter', versions['flutter'])
    require_version('dart', versions['dart'])
    executable = release / 'boohtacord_desktop.exe'
    destination = ROOT / '.out/screen-setup-windows'
    destination.mkdir(parents=True, exist_ok=False)
    root = Path(os.environ['RUNNER_TEMP']) / ('qa337-' + secrets.token_hex(8))
    stack = Stack(root)
    config = Path(os.environ['APPDATA']) / 'ru.boohtacord/boohtacord_desktop/issue337-acceptance-private.json'
    owned_config = False
    process = None
    try:
        if config.exists() or running_at(executable):
            raise RuntimeError('Refusing existing user configuration or client')
        stack.start()
        config.parent.mkdir(parents=True, exist_ok=True)
        with config.open('x', encoding='utf-8') as handle:
            json.dump(stack.private_configuration(), handle)
        owned_config = True
        with (root / 'private-client.log').open('xb') as log:
            process = subprocess.Popen([str(executable)], cwd=release,
                                       stdout=log, stderr=subprocess.STDOUT,
                                       env=dict(os.environ, BOOHTACORD_WINDOWS_GUI_ACCEPTANCE='1'))
            driver = root / 'driver'
            deadline = time.monotonic() + 180
            while time.monotonic() < deadline:
                if (driver / 'failure.json').exists():
                    failure = retain_failure(driver, destination)
                    raise RuntimeError('Actual Windows GUI failed: ' + json.dumps(failure))
                if (driver / 'result.json').exists():
                    value = json.loads((driver / 'result.json').read_text())
                    validate_result(value)
                    value.update(source=output('git', 'rev-parse', 'HEAD'),
                                 flutter=versions['flutter'], dart=versions['dart'],
                                 manifest_sha256=binding['release']['artifact-manifest.json']['sha256'],
                                 build_scope='CI acceptance package; stable release NOT_RUN')
                    images = []
                    for name in [*(row['case'] + '.png' for row in value['cases']),
                                 'header-open.png', 'dock-open.png',
                                 'header-footer.png', 'dock-footer.png']:
                        image = driver / name
                        if not image.is_file(): raise RuntimeError('GUI capture missing')
                        raw = image.read_bytes()
                        if len(raw) > 2_000_000: raise RuntimeError('GUI capture exceeds evidence bound')
                        shutil.copyfile(image, destination / name)
                        images.append({'file': name, 'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)})
                        # Synthetic disposable runner UI only; never a personal desktop.
                        # Makes pixels reviewable even when artifact API is unavailable.
                        encoded = base64.b64encode(raw).decode()
                        chunks = [encoded[offset:offset + 8192] for offset in range(0, len(encoded), 8192)]
                        for index, chunk in enumerate(chunks):
                            print(f'QA288_CAPTURE_CHUNK:{name}:{index}:{len(chunks)}:{chunk}', flush=True)
                    value['captures'] = images
                    (destination / 'result.json').write_text(json.dumps(value, indent=2), encoding='utf-8')
                    print('QA288_RESULT_BASE64:' + base64.b64encode(json.dumps(value).encode()).decode(), flush=True)
                    print('PASS: Windows footer geometry, scrollable quality, OS traversal/Escape, focus and real SFU continuity', flush=True)
                    return
                if process.poll() is not None: raise RuntimeError('QA Windows client exited before acceptance')
                time.sleep(.2)
            raise RuntimeError('Windows GUI acceptance timed out')
    finally:
        try:
            if process is not None and running_at(executable): close_owned(executable)
        finally:
            try:
                if owned_config: config.unlink(missing_ok=True)
            finally:
                if root.exists(): stack.close()


if __name__ == '__main__':
    main()
