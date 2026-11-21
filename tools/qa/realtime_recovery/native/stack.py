"""Dedicated native fixture: real API/SFU, no shared QA or production resources."""
import os
import subprocess
from tools.audio.livekit_fixture import IMAGE
from tools.qa.client_lifecycle.services import LABEL, output, ports_available, read_only_directory_mount, run
from tools.qa.realtime_recovery.config import ORIGIN, PORTS, sfu
from tools.qa.realtime_recovery.stack import Stack as Base, ready
from .endpoint import validate_endpoint


class Stack(Base):
    def start(self):
        endpoint = os.environ.get('DOCKER_HOST')
        if not endpoint:
            context = output('docker', 'context', 'show')
            endpoint = output('docker', 'context', 'inspect', context,
                              '--format', '{{.Endpoints.docker.Host}}')
        validate_endpoint(endpoint, output('docker', 'info', '--format', '{{.OSType}}'))
        ports_available(PORTS)
        self.environment.update(PUBLIC_ORIGIN=ORIGIN, OTEL_SDK_DISABLED='true',
            LIVEKIT_PUBLIC_WS_URL='wss://localhost:4910/qa-sfu',
            LIVEKIT_PRIVATE_HTTP_URL=f'http://{self.owner}-sfu:4980')
        run('docker', 'network', 'create', '--label', LABEL+'='+self.owner,
            self.owner, stdout=subprocess.DEVNULL)
        self.resources.append(('network', self.owner))
        self.container('db', 'postgres:17.6-alpine', '--tmpfs', '/var/lib/postgresql/data',
            '-e', 'POSTGRES_DB=qa', '-e', 'POSTGRES_USER=qa', '-e', 'POSTGRES_PASSWORD=qa-disposable-only')
        run('docker', 'exec', self.owner+'-db', 'sh', '-c',
            'until pg_isready -U qa -d qa; do sleep .2; done', stdout=subprocess.DEVNULL)
        run('docker', 'build', '--label', LABEL+'='+self.owner, '--tag', self.image,
            '--file', str(self.root/'backend/Dockerfile'), str(self.root/'backend'), stdout=subprocess.DEVNULL)
        self.resources.append(('image', self.image))
        self.migrate(); self.bootstrap()
        self.container('redis', 'redis:7.4.12-alpine', command=(
            'redis-server', '--save', '', '--appendonly', 'no', '--protected-mode', 'no'))
        configs = self.work/'sfu'; configs.mkdir()
        (configs/'livekit.yaml').write_text(sfu(self.owner), encoding='utf-8')
        self.container('sfu', IMAGE, '--publish', '127.0.0.1:4980:4980/tcp',
            '--publish', '127.0.0.1:4981:4981/tcp', '--publish', '127.0.0.1:4982:4982/udp',
            *read_only_directory_mount(configs, '/qa-config'),
            command=('--config', '/qa-config/livekit.yaml', '--node-ip', '127.0.0.1'))
        ready('http://127.0.0.1:4980')
        self.start_api()
        configs = self.work/'proxy'; configs.mkdir()
        (configs/'Caddyfile').write_text('''{
 admin off
 auto_https disable_redirects
}
https://localhost:4910 {
 bind 0.0.0.0
 tls internal
 handle /qa-sfu* {
  uri strip_prefix /qa-sfu
  reverse_proxy '''+self.owner+'''-sfu:4980
 }
 handle /api/* {
  reverse_proxy '''+self.owner+'''-api:8080
 }
}
''', encoding='utf-8')
        self.container('proxy', 'caddy:2.10.0-alpine', '--publish', '127.0.0.1:4910:4910',
                       *read_only_directory_mount(configs, '/etc/caddy'))
        ready(ORIGIN+'/api/v1/health')
