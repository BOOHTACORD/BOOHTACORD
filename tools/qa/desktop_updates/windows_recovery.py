"""Exercise the real recovery EXE against a retained Flutter release on Windows.

This component gate covers failed apply, real relaunch and one-shot recovery.
It does not certify an N -> N+1 UI journey or workspace restoration.
"""
import argparse
import ctypes
from ctypes import wintypes
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


def digest(file):
    with file.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def running_at(executable):
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.QueryFullProcessImageNameW.argtypes = [
        wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR,
        ctypes.POINTER(wintypes.DWORD)]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.K32EnumProcesses.argtypes = [ctypes.POINTER(wintypes.DWORD),
                                      wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
    process_ids = (wintypes.DWORD * 8192)()
    used = wintypes.DWORD()
    if not kernel.K32EnumProcesses(process_ids, ctypes.sizeof(process_ids),
                                  ctypes.byref(used)):
        raise OSError('Could not inspect owned test processes')
    result = []
    for process_id in process_ids[:used.value // ctypes.sizeof(wintypes.DWORD)]:
        handle = kernel.OpenProcess(0x1000, False, process_id)
        if not handle:
            continue
        try:
            buffer = ctypes.create_unicode_buffer(32768)
            length = wintypes.DWORD(len(buffer))
            if kernel.QueryFullProcessImageNameW(handle, 0, buffer,
                                                ctypes.byref(length)):
                if os.path.normcase(buffer.value) == os.path.normcase(str(executable)):
                    result.append(process_id)
        finally:
            kernel.CloseHandle(handle)
    return result


def close_owned(executable):
    processes = set(running_at(executable))
    user = ctypes.WinDLL('user32', use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]

    @callback_type
    def close(window, _):
        owner = wintypes.DWORD()
        user.GetWindowThreadProcessId(window, ctypes.byref(owner))
        if owner.value in processes:
            user.PostMessageW(window, 0x0010, 0, 0)  # WM_CLOSE, never TerminateProcess.
        return True

    user.EnumWindows(close, 0)
    deadline = time.monotonic() + 15
    while running_at(executable) and time.monotonic() < deadline:
        time.sleep(0.25)
    if running_at(executable):
        raise RuntimeError('Owned restored app did not accept graceful close')


def run(release, build, output):
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
    shutil.copy2(release / monitor.name, monitor)
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
    started = time.monotonic()
    process = subprocess.Popen([str(monitor), '--plan', str(plan)])
    try:
        ready = recovery / 'recovery-ready.json'
        deadline = time.monotonic() + 20
        while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.1)
        if not ready.exists():
            raise RuntimeError('Recovery did not arm for the real retained baseline')
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
            'whole_baseline_hashes_match': True, 'unicode_paths': True,
            'synthetic_external_profile_retained': True,
            'finished_transaction_replay_noop': True,
            'one_shot_registration_removed': True,
            'n_to_n1_ui_acceptance': 'NOT_RUN',
        }, indent=2) + '\n')
    finally:
        if process.poll() is None:
            (recovery / 'cancel.json').write_text(json.dumps({'transaction': transaction}))
            process.wait(timeout=10)
        close_owned(executable)
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                            r'Software\Microsoft\Windows\CurrentVersion\RunOnce',
                            0, winreg.KEY_SET_VALUE) as key:
            try:
                winreg.DeleteValue(key, 'BOOHTACORDRecovery-' + transaction)
            except FileNotFoundError:
                pass
        if marker.read_text() == 'issue337\n':
            shutil.rmtree(root)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--release', type=Path, required=True)
    parser.add_argument('--build')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    from tools.build.client_identity import load
    run(args.release, args.build or load('windows')['native_build'], args.output)
