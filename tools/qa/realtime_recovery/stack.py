"""Own a real R1-only stack without occupying shared acceptance ports."""
import ssl
import subprocess
import time
import urllib.error
import urllib.request
from tools.audio.livekit_fixture import IMAGE
from tools.qa.client_lifecycle.services import LABEL, local_docker, ports_available, read_only_directory_mount, run
from tools.qa.client_lifecycle.stack import ATTACHMENT_TMPFS, Stack as Base
from .config import ORIGIN, PORTS, proxy, sfu


def ready(url):
    allowed = ('http://127.0.0.1:4920/', 'http://127.0.0.1:4980', ORIGIN + '/')
    if not url.startswith(allowed):
        raise ValueError('Only the dedicated owned readiness endpoints are allowed')
    for _ in range(150):
        try:
            context = ssl._create_unverified_context() if url.startswith(ORIGIN + '/') else None
            with urllib.request.urlopen(url, timeout=1, context=context) as response:
                if response.status == 200:
                    return
        except (OSError, urllib.error.HTTPError):
            time.sleep(.2)
    raise RuntimeError('Dedicated R1 service did not become ready')


class Stack(Base):
    def start(self):
        local_docker()
        ports_available(PORTS)
        self.environment.update(PUBLIC_ORIGIN=ORIGIN, LIVEKIT_PUBLIC_WS_URL=ORIGIN.replace('https:', 'wss:') + '/qa-sfu',
            LIVEKIT_PRIVATE_HTTP_URL=f'http://{self.owner}-sfu:4980', OTEL_SDK_DISABLED='true')
        run('docker', 'network', 'create', '--label', LABEL + '=' + self.owner, self.owner,
            stdout=subprocess.DEVNULL)
        self.resources.append(('network', self.owner))
        self.container('db', 'postgres:17.6-alpine', '--tmpfs', '/var/lib/postgresql/data',
            '-e', 'POSTGRES_DB=qa', '-e', 'POSTGRES_USER=qa', '-e', 'POSTGRES_PASSWORD=qa-disposable-only')
        run('docker', 'exec', self.owner + '-db', 'sh', '-c',
            'until pg_isready -U qa -d qa; do sleep .2; done', stdout=subprocess.DEVNULL)
        run('docker', 'build', '--label', LABEL + '=' + self.owner, '--tag', self.image,
            '--file', str(self.root / 'backend/Dockerfile'), str(self.root / 'backend'), stdout=subprocess.DEVNULL)
        self.resources.append(('image', self.image))
        self.migrate(); self.bootstrap()
        self.container('redis', 'redis:7.4.12-alpine', command=(
            'redis-server', '--save', '', '--appendonly', 'no', '--protected-mode', 'no'))
        configs = self.work / 'sfu'; configs.mkdir()
        (configs / 'livekit.yaml').write_text(sfu(self.owner)); (configs / 'livekit.yaml').chmod(0o644)
        self.container('sfu', IMAGE, '--publish', '127.0.0.1:4980:4980/tcp',
            '--publish', '127.0.0.1:4981:4981/tcp', '--publish', '127.0.0.1:4982:4982/udp',
            *read_only_directory_mount(configs, '/qa-config'),
            command=('--config', '/qa-config/livekit.yaml', '--node-ip', '127.0.0.1'))
        ready('http://127.0.0.1:4980')
        self.start_api()
        configs = self.work / 'proxy'; configs.mkdir()
        (configs / 'Caddyfile').write_text(proxy(self.owner, self.root))
        self.container('proxy', 'caddy:2.10.0-alpine', '--publish', '127.0.0.1:4910:4910',
            '-v', str(self.root) + ':' + str(self.root) + ':ro',
            *read_only_directory_mount(configs, '/etc/caddy'))
        ready(ORIGIN + '/api/v1/health')

    def start_api(self):
        arguments = ['--publish', '127.0.0.1:4920:8080', '--tmpfs', ATTACHMENT_TMPFS]
        for key, value in self.environment.items():
            arguments.extend(('--env', key + '=' + value))
        self.container('api', self.image, *arguments)
        self.api = self.owner + '-api'
        ready('http://127.0.0.1:4920/api/v1/health')
