"""Root-owned host controller: one JIT runner and one fresh unprivileged guest per job."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import subprocess
import tempfile
import time

API = 'repos/Egkurilov/BOOHTACORD/actions/runners'
BASE = 'boohtacord-ci-base'
RUNTIME = Path(os.environ.get('RUNTIME_DIRECTORY', '/run/boohtacord-ci'))
LABELS = ['self-hosted', 'linux', 'x64', 'boohtacord-ci-ephemeral']


def command(args, *, stdin=None, timeout=120, quiet=False, check=True):
    result = subprocess.run(args, input=stdin, text=True, timeout=timeout,
                            stdout=subprocess.DEVNULL if quiet else subprocess.PIPE,
                            stderr=subprocess.STDOUT if not quiet else subprocess.DEVNULL)
    if check and result.returncode:
        # Never include subprocess output: registration responses contain credentials.
        raise RuntimeError('Runner operation failed: ' + ' '.join(args[:2]) + ' status ' + str(result.returncode))
    return result.stdout or ''


def verify_base():
    data = json.loads(command(['lxc', 'query', '/1.0/instances/' + BASE]))
    config, devices = data['expanded_config'], data['expanded_devices']
    if not (config.get('security.privileged') == 'false'
            and config.get('security.idmap.isolated') == 'true'
            and config.get('limits.cpu') == '2' and config.get('limits.memory') == '4GiB'
            and set(devices) == {'root', 'eth0'}
            and devices['root'].get('type') == 'disk' and devices['root'].get('path') == '/'
            and devices['root'].get('pool') == 'boohtacord-ci'
            and not devices['root'].get('source')
            and devices['eth0'].get('type') == 'nic'
            and devices['eth0'].get('network') == 'boohtaci0'):
        raise ValueError('CI base isolation differs from the approved pool')


def wait_for_boot(guest):
    # lxc start returns before guest PID 1 has created its system bus.
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        state = command(['lxc', 'exec', guest, '--disable-stdin', '--', 'systemctl',
                         'is-system-running'], check=False, timeout=15).strip()
        if state in ('running', 'degraded'):
            return
        time.sleep(2)
    raise RuntimeError('Guest boot is not ready for registration')


def cycle(slot):
    if slot not in ('1', '2', '3', '4'):
        raise ValueError('Only four bounded CI slots are configured')
    verify_base()
    guest = 'boohtacord-ci-' + slot
    command(['lxc', 'delete', '--force', guest], check=False)
    identity = None
    token_path = None
    try:
        clone = ['lxc', 'copy', BASE, guest, '--ephemeral']
        metadata = slot in ('3', '4')
        if metadata:
            clone += ['--config', 'limits.cpu=1', '--config', 'limits.memory=512MiB']
        command(clone)
        command(['lxc', 'start', guest])
        wait_for_boot(guest)
        name = ('BOOHTACORD-Hetzner-CI-' + slot + '-' +
                datetime.now(timezone.utc).strftime('%H%M%S') + '-' + secrets.token_hex(3))
        labels = LABELS if not metadata else [*LABELS[:3], 'boohtacord-ci-meta']
        payload = json.dumps(dict(name=name, runner_group_id=1, labels=labels, work_folder='_work'))
        registration = json.loads(command(['gh', 'api', '--method', 'POST', API + '/generate-jitconfig',
                                           '--input', '-'], stdin=payload))
        identity = registration['runner']['id']
        RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode='w', dir=RUNTIME, delete=False) as stream:
            token_path = Path(stream.name)
            stream.write(registration['encoded_jit_config'])
        command(['lxc', 'file', 'push', str(token_path), guest + '/home/runner/.jit',
                 '--uid', '1001', '--gid', '1001', '--mode', '0600'])
        token_path.unlink()
        token_path = None
        source = Path(__file__).parent
        command(['lxc', 'file', 'push', str(source / 'start-runner.sh'),
                 guest + '/home/runner/actions-runner/start-ci.sh', '--mode', '0755'])
        command(['lxc', 'file', 'push', str(source / 'guest-runner.service'),
                 guest + '/etc/systemd/system/boohtacord-agent.service', '--mode', '0644'])
        execute = ['lxc', 'exec', guest, '--disable-stdin', '--', 'systemctl']
        command([*execute, 'daemon-reload'])
        command([*execute, 'start', 'boohtacord-agent'])
        # The agent is owned by guest PID 1, independent of a long-lived LXD exec session.
        deadline = time.monotonic() + 6 * 60 * 60
        while time.monotonic() < deadline:
            raw = command([*execute, 'show', 'boohtacord-agent', '-p', 'ActiveState', '-p', 'ExecMainStatus'])
            state = dict(line.split('=', 1) for line in raw.splitlines() if '=' in line)
            if state.get('ActiveState') in ('inactive', 'failed'):
                if state.get('ExecMainStatus') != '0':
                    raise RuntimeError('Guest agent exited unsuccessfully')
                return
            time.sleep(5)
        raise RuntimeError('Guest agent exceeded maximum execution time')
    finally:
        if token_path is not None:
            token_path.unlink(missing_ok=True)
        command(['lxc', 'delete', '--force', guest], timeout=120, check=False)
        if identity is not None:
            command(['gh', 'api', '--method', 'DELETE', API + '/' + str(identity)], check=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('slot', choices=('1', '2', '3', '4'))
    args = parser.parse_args()
    def stop(_signum, _frame):
        raise RuntimeError('Worker shutdown')
    signal.signal(signal.SIGTERM, stop)
    try:
        while True:
            if shutil.disk_usage('/').free < 5 * 1024 ** 3:
                raise RuntimeError('Host disk reserve reached')
            usage = json.loads(command(['lxc', 'query', '/1.0/storage-pools/boohtacord-ci/resources']))['space']
            if usage['total'] - usage['used'] < 2 * 1024 ** 3:
                raise RuntimeError('CI storage reserve reached')
            cycle(args.slot)
            time.sleep(2)
    except RuntimeError as error:
        raise SystemExit(str(error)) from None
    except Exception as error:
        raise SystemExit('CI worker cycle failed: ' + type(error).__name__ + '; guest cleanup attempted') from None


if __name__ == '__main__':
    main()
