"""Shared bounded pinned-SSH delivery of one artifact using current trusted control code."""
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import signal
import tempfile
from .commands import execute
from .payload import inspect
from .phases import Phases, PhaseFailed
from .readback_contract import validate as acknowledgement

DRIVER_PATHS = ('tools/release/archive', 'tools/release/bundle', 'tools/release/install',
                'tools/release/delivery/commands.py', 'tools/verify/oci/verify_oci.py')


class Transfer:
    def __init__(self, source, controller, incoming, temporary, home, user, address, *, executor=execute, nonce=None):
        self.phases = Phases(source, controller, executor=executor)
        self.source, self.controller, self.execute = source, controller, executor
        self.nonce = secrets.token_hex(16) if nonce is None else nonce
        if (not isinstance(user, str) or not re.fullmatch('[a-z_][a-z0-9_-]{0,31}', user)
                or not isinstance(self.nonce, str) or not re.fullmatch('[a-f0-9]{32}', self.nonce)):
            raise ValueError('Invalid delivery transport identity')
        try: host = ipaddress.ip_address(address)
        except ValueError: raise ValueError('Invalid delivery address') from None
        self.incoming, self.temporary, self.home = map(Path, (incoming, temporary, home))
        if any(not p.is_absolute() or p.resolve() != p or not p.is_dir() for p in (self.temporary, self.home)):
            raise ValueError('Delivery local paths are not canonical')
        self.remote = user + '@' + str(host)
        self.scp_remote = user + '@' + ('[' + str(host) + ']' if host.version == 6 else str(host))
        self.stage = '/tmp/voice-platform-delivery-' + self.nonce
        self.options = ['-i', str(self.home/'.ssh/id_deploy'), '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
                        '-o', 'UserKnownHostsFile=' + str(self.home/'.ssh/known_hosts'), '-o', 'ConnectTimeout=10',
                        '-o', 'ConnectionAttempts=1', '-o', 'ServerAliveInterval=10', '-o', 'ServerAliveCountMax=2']
        self.scripts = Path(__file__).parent

    def prepare(self):
        payload = inspect(self.incoming, self.source)
        head = self.execute(['git', 'rev-parse', 'HEAD'], 10, capture_limit=128).decode('ascii').strip()
        if head != self.controller: raise ValueError('Delivery controller checkout differs')
        self.execute(['git', 'diff', '--exit-code', 'HEAD', '--'], 10)
        self.execute(['git', 'merge-base', '--is-ancestor', self.source, self.controller], 10)
        driver = self.temporary/(self.source + '.installer.tar.gz')
        if driver.exists() or driver.is_symlink(): raise ValueError('Delivery driver already exists')
        self.execute(['git', 'archive', '--format=tar.gz', '--output=' + str(driver), self.controller,
                      '--', *DRIVER_PATHS], 30)
        if driver.is_symlink() or not driver.is_file() or not 0 < driver.stat().st_size <= 20_000_000:
            raise ValueError('Invalid delivery driver archive')
        with driver.open('rb') as stream: digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        return payload, driver, digest

    def ssh(self, *args):
        return ['ssh', *self.options, self.remote, 'sudo', '-n', 'bash', '-s', '--', *args]

    def run(self):
        payload, driver, driver_sha = self.prepare()
        def current(raw):
            if not re.fullmatch(b'[a-f0-9]{40}\n', raw): raise ValueError('Invalid running source identity')
            return raw.decode().strip()
        with tempfile.TemporaryFile() as stream:
            header = ('set -euo pipefail\nnonce="$1"\n[[ "$nonce" =~ ^[0-9a-f]{32}$ ]]\n'
                      'umask 077\nmkdir -m 700 -- "/tmp/voice-platform-delivery-$nonce"\n'
                      "sudo -n bash -s <<'CURRENT'\n")
            stream.write(header.encode() + (self.scripts/'current_revision.sh').read_bytes() + b'\nCURRENT\n')
            stream.seek(0)
            # The stage is created as the unprivileged SSH user, before root verification.
            argv = ['ssh', *self.options, self.remote, 'bash', '-s', '--', self.nonce]
            prior = self.phases.run('current_revision', argv, stdin=stream, validator=current, capture_limit=128)
        self.phases.run('history', ['git', 'merge-base', '--is-ancestor', prior, self.source])
        for phase, path, suffix in (('transfer_bundle', payload['path'], '.release.tar.gz'),
                                    ('transfer_driver', driver, '.installer.tar.gz')):
            self.phases.run(phase, ['scp', '-B', *self.options, str(path), self.scp_remote + ':' + self.stage + '/' + self.source + suffix])
        with (self.scripts/'install_received.sh').open('rb') as stream:
            self.phases.run('remote_install', self.ssh(self.source, payload['sha256'], driver_sha, prior, self.controller, self.nonce), stdin=stream)
        with (self.scripts/'read_received.sh').open('rb') as stream:
            result = self.phases.run('readback', self.ssh(self.source, driver_sha, self.controller, self.nonce),
                                     stdin=stream, capture_limit=16384,
                                     validator=lambda raw: acknowledgement(raw, self.source, self.controller, prior, self.nonce))
        return {**self.phases.complete(), 'readback': result}


def main():
    def interrupted(signum, frame):
        raise SystemExit(128 + signum)
    signal.signal(signal.SIGTERM, interrupted)
    value = Transfer(os.environ['RELEASE_REVISION'], os.environ['CONTROLLER_REVISION'], Path.cwd()/'.out/incoming',
                     Path(os.environ['RUNNER_TEMP']), Path.home(), os.environ['SSH_USER'], os.environ['DEPLOY_SERVER_IP'])
    result = None
    try:
        result = value.run()
    except Exception:
        raise SystemExit('Bounded delivery failed; inspect the sanitized phase receipt') from None
    finally:
        path = Path.cwd()/'.out/delivery/transfer.json'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(result if result is not None else value.phases.failure(), sort_keys=True) + '\n')
    print('Fresh installed-source delivery acknowledgement verified')


if __name__ == '__main__': main()
