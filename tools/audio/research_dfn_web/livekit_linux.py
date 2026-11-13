"""A local Linux LiveKit with private ICE and ephemeral fixture credentials."""
from contextlib import contextmanager
from pathlib import Path
import secrets
import subprocess
import tempfile
import time
from urllib.request import urlopen

from tools.audio.livekit_fixture import IMAGE
from .livekit_windows import is_private_test_ip, local_address, probe_environment


def make_server_config(key, secret):
    if not key.isalnum() or not secret.isalnum():
        raise ValueError('Invalid fixture credentials')
    return (f'port: 7880\nbind_addresses: ["0.0.0.0"]\nkeys:\n  {key}: {secret}\n'
            'rtc:\n  udp_port: 7882\n  use_external_ip: false\n')


def docker_command(name, config, host):
    if not is_private_test_ip(host) or not name.replace('-', '').isalnum():
        raise ValueError('Invalid fixture interface or name')
    return ['docker', 'run', '--rm', '-d', '--name', name,
            '-p', '127.0.0.1:17880:7880/tcp', '-p', f'{host}:7882:7882/udp',
            '--mount', f'type=bind,src={config},dst=/fixture.yaml,readonly',
            IMAGE, '--config', '/fixture.yaml', '--node-ip', host]


@contextmanager
def private_sfu(inherited):
    host, key, secret = local_address(), 'probe' + secrets.token_hex(8), secrets.token_hex(32)
    name = 'boohta-audio-' + secrets.token_hex(6)
    with tempfile.TemporaryDirectory(prefix='boohta-livekit-linux-') as directory:
        config = Path(directory) / 'fixture.yaml'
        config.write_text(make_server_config(key, secret), encoding='utf-8')
        try:
            subprocess.run(docker_command(name, str(config), host), check=True, stdout=subprocess.DEVNULL)
            for attempt in range(30):
                try:
                    with urlopen('http://127.0.0.1:17880', timeout=1) as response:
                        if response.status == 200: break
                except OSError:
                    pass
                if attempt == 29: raise RuntimeError('Local SFU readiness timeout')
                time.sleep(1)
            yield probe_environment(inherited, key, secret)
        finally:
            subprocess.run(['docker', 'rm', '-f', name], check=False, capture_output=True)
