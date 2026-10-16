"""Exercise the real recovery EXE against a retained Flutter release on Windows.

This component gate covers failed apply, real relaunch and one-shot recovery.
It does not certify an N -> N+1 UI journey or workspace restoration.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

from .windows_process import running_at, close_owned


def digest(file):
    with file.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def run(release, build, output, monitor_override=None):
    if sys.platform != 'win32':
        raise RuntimeError('This native gate requires Windows')
    import winreg
    release = release.resolve()
    if not (release / 'boohtacord_desktop.exe').is_file():
        raise ValueError('A real built Flutter release is required')
    root = Path(tempfile.mkdtemp(prefix='BOOHTACORD-337-', dir=os.environ['LOCALAPPDATA']))
    marker = root / '.owned-recovery-gate'
    marker.write_text('issue337\n')
    recovery = root / 'DesktopUpdates/Проверка с пробелами/recovery'
    recovery.mkdir(parents=True)
    target = root / 'Установка с пробелами/current'
    target.parent.mkdir()
    executable = target / 'boohtacord_desktop.exe'
    monitor = recovery / 'BOOHTACORDRecovery.exe'
    shutil.copy2(monitor_override or release / monitor.name, monitor)
    backup = recovery / 'previous'
    shutil.copytree(release, backup)
    files = {file.relative_to(backup).as_posix(): digest(file)
             for file in backup.rglob('*') if file.is_file()}
    if not files or len(files) > 5000:
        raise ValueError('Unexpected release baseline size')
    (recovery / 'baseline.json').write_text(json.dumps({
        'schema_version': 1, 'files': files,
    }), encoding='utf-8')
    # Synthetic local profile lives outside the replaced directory.
    profile = root / 'profile/sentinel.json'
    profile.parent.mkdir()
    profile.write_text('{"synthetic":true,"draft":"retained"}\n')
    profile_hash = digest(profile)
    transaction = str(uuid.uuid4())
    plan = recovery / 'plan.json'
    plan.write_text(json.dumps({
        'schema_version': 1, 'transaction': transaction,
        'target': str(target), 'backup': str(backup), 'old_pid': 0,
        'old_build': build, 'new_build': str(int(build) + 1),
        'new_release': 'owned-failed-apply',
    }), encoding='utf-8')
    # Match the shipping client's launch: its working directory may be current.
    # The external monitor must release that directory before declaring Ready.
    target.mkdir()
    started = time.monotonic()
    process = subprocess.Popen([str(monitor), '--plan', str(plan)], cwd=target)
    try:
        ready = recovery / 'recovery-ready.json'
        deadline = time.monotonic() + 20
        while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.1)
        if not ready.exists():
            raise RuntimeError('Recovery did not arm; native exit=' + str(process.poll()))
        moved = target.parent / 'moved-current'
        try:
            target.rename(moved)
        except OSError:
            raise RuntimeError('Recovery retained a lock on inherited current directory') from None
        moved.rmdir()
        # Simulate only the failed replacement (no target). The shipping monitor,
        # its actual 120s deadline, real app files and relaunch are not mocked.
        if process.wait(timeout=170) != 0:
            raise RuntimeError('Recovery monitor failed')
        outcome = json.loads((recovery / 'recovery-outcome.json').read_text())
        if outcome != {'transaction': transaction, 'status': 'rolledBack',
                       'reason': 'local_bootstrap'}:
            raise RuntimeError('Failed apply did not restore the retained version')
        for relative, expected in files.items():
            if digest(target / relative) != expected:
                raise RuntimeError('Restored application differs from baseline')
        deadline = time.monotonic() + 20
        while not running_at(executable) and time.monotonic() < deadline:
            time.sleep(0.25)
        if not running_at(executable):
            raise RuntimeError('Real restored Flutter application did not start')
        time.sleep(3)
        if not running_at(executable):
            raise RuntimeError('Restored Flutter application exited immediately')
        if digest(profile) != profile_hash:
            raise RuntimeError('External synthetic profile was modified')
        close_owned(executable)
        # Replaying an already-finished transaction must not relaunch the app.
        subprocess.run([str(monitor), '--plan', str(plan)], check=True, timeout=10)
        if running_at(executable):
            raise RuntimeError('Finished recovery transaction relaunched again')
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                            r'Software\Microsoft\Windows\CurrentVersion\RunOnce') as key:
            try:
                winreg.QueryValueEx(key, 'BOOHTACORDRecovery-' + transaction)
            except FileNotFoundError:
                pass
            else:
                raise RuntimeError('Finished recovery left its RunOnce registration')
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps({
            'schema_version': 1, 'status': 'PASS', 'native_build': build,
            'elapsed_seconds': round(time.monotonic() - started),
            'real_monitor': True, 'real_flutter_relaunch': True,
            'inherited_current_directory_released': True,
            'whole_baseline_hashes_match': True, 'unicode_paths': True,
            'synthetic_external_profile_retained': True,
            'finished_transaction_replay_noop': True,
            'one_shot_registration_removed': True,
            'n_to_n1_ui_acceptance': 'NOT_RUN',
        }, indent=2) + '\n')
    except Exception:
        output.parent.mkdir(parents=True, exist_ok=True)
        result = {'schema_version': 1, 'status': 'FAIL', 'monitor_exit': process.poll(),
                  'elapsed_seconds': round(time.monotonic() - started)}
        outcome_file = recovery / 'recovery-outcome.json'
        if outcome_file.exists():
            value = json.loads(outcome_file.read_text())
            for key in ['status', 'reason']:
                observed = value.get(key)
                if isinstance(observed, str) and len(observed) <= 64:
                    result['native_' + key] = observed
        output.write_text(json.dumps(result, indent=2) + '\n')
        raise
    finally:
        if process.poll() is None:
            (recovery / 'cancel.json').write_text(json.dumps({'transaction': transaction}))
            process.wait(timeout=10)
        close_owned(executable)
        try:
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                            r'Software\Microsoft\Windows\CurrentVersion\RunOnce',
                            0, winreg.KEY_SET_VALUE)
        except FileNotFoundError:
            key = None
        if key is not None:
            try:
                winreg.DeleteValue(key, 'BOOHTACORDRecovery-' + transaction)
            except FileNotFoundError:
                pass
            finally:
                key.Close()
        if marker.read_text() == 'issue337\n':
            shutil.rmtree(root)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--release', type=Path, required=True)
    parser.add_argument('--build')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--monitor', type=Path)
    args = parser.parse_args()
    from tools.build.client_identity import load
    run(args.release, args.build or load('windows')['native_build'], args.output, args.monitor)
