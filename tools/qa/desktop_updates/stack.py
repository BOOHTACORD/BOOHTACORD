"""Owned loopback-only real API/PostgreSQL/SFU for installed updater journeys."""
import json
from pathlib import Path
import secrets
import ssl
import subprocess
import time
import urllib.request

from tools.audio.livekit_fixture import IMAGE as SFU_IMAGE
from tools.qa.client_lifecycle.services import LABEL, local_docker, ports_available, run
from tools.qa.client_lifecycle.stack import Stack as Base


class Stack(Base):
    def __init__(self, root, work):
        super().__init__(root, work)
        self.owner = 'qa337-' + secrets.token_hex(8)
        self.image = 'boohtacord-issue337-api:3427493618ec'
        self.environment.update({
            'DATABASE_URL': f'postgres://qa:qa-disposable-only@{self.owner}-db:5432/qa?sslmode=disable',
            'PUBLIC_ORIGIN': 'https://localhost:4910',
            'LIVEKIT_PUBLIC_WS_URL': 'wss://localhost:4910/qa-sfu',
            'LIVEKIT_PRIVATE_HTTP_URL': f'http://{self.owner}-sfu:4912',
            'CLIENT_UPDATE_CATALOG_PATH': '/client-catalog.json',
            'CLIENT_UPDATE_ALLOWED_HOSTS': 'github.com',
        })
        self.environment.pop('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', None)

    def start(self):
        local_docker()
        ports_available((4910, 4914, 4915))
        self.work.mkdir(parents=True, exist_ok=False)
        self.work.chmod(0o700)
        run('docker', 'network', 'create', '--label', LABEL + '=' + self.owner,
            self.owner, stdout=subprocess.DEVNULL)
        self.resources.append(('network', self.owner))
        self.container('db', 'postgres:17.6-alpine', '--tmpfs', '/var/lib/postgresql/data',
                       '-e', 'POSTGRES_DB=qa', '-e', 'POSTGRES_USER=qa',
                       '-e', 'POSTGRES_PASSWORD=qa-disposable-only')
        run('docker', 'exec', self.owner + '-db', 'sh', '-c',
            'until pg_isready -h 127.0.0.1 -U qa -d qa; do sleep .2; done', stdout=subprocess.DEVNULL)
        self.migrate()
        self.bootstrap()
        catalog = self.work / 'catalog.json'
        catalog.write_text(json.dumps({'schema_version': 1, 'catalog_revision': 1,
                                      'application_family': 'boohtacord', 'entries': []}))
        catalog.chmod(0o644)
        self.start_api()
        sfu = self.work / 'livekit.yaml'
        sfu.write_text(f'''port: 4912
bind_addresses: ["0.0.0.0"]
rtc:
  tcp_port: 4914
  udp_port: 4915
  use_external_ip: false
  enable_loopback_candidate: true
  interfaces:
    includes: ["eth0"]
keys:
  qa-only: qa-local-only-secret-12345
webhook:
  api_key: qa-only
  urls: ["http://{self.owner}-api:8080/internal/livekit/roster"]
''')
        self.container('sfu', SFU_IMAGE, '--publish', '127.0.0.1:4914:4914/tcp',
                       '--publish', '127.0.0.1:4915:4915/udp', '-v', str(sfu) + ':/qa.yaml:ro',
                       command=('--config', '/qa.yaml', '--node-ip', '127.0.0.1'))
        config = self.work / 'Caddyfile'
        config.write_text('''{
  admin off
  auto_https disable_redirects
}
https://localhost:4910 {
  bind 0.0.0.0
  tls internal
  handle /qa-sfu* {
    uri strip_prefix /qa-sfu
    reverse_proxy SFU:4912
  }
  handle /api/* {
    reverse_proxy API:8080
  }
}
'''.replace('SFU', self.owner + '-sfu').replace('API', self.owner + '-api'))
        run('docker', 'run', '--rm', '--network', 'none', '-v', str(config) + ':/etc/caddy/Caddyfile:ro', 'caddy:2.10.0-alpine', 'caddy', 'validate', '--config', '/etc/caddy/Caddyfile', '--adapter', 'caddyfile')
        self.container('proxy', 'caddy:2.10.0-alpine', '--publish', '127.0.0.1:4910:4910',
                       '--tmpfs', '/data', '--tmpfs', '/config',
                       '-v', str(config) + ':/etc/caddy/Caddyfile:ro')
        certificate = self.work / 'owned-root.crt'
        for _ in range(80):
            # Docker's archive endpoint cannot read this container's tmpfs mount.
            copied = subprocess.run(['docker', 'exec', self.owner + '-proxy', 'cat',
                                     '/data/caddy/pki/authorities/local/root.crt'],
                                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            if copied.returncode == 0 and copied.stdout.startswith(b'-----BEGIN CERTIFICATE-----'):
                certificate.write_bytes(copied.stdout)
                break
            time.sleep(.25)
        if not certificate.is_file():
            raise RuntimeError('Owned TLS root was not generated')
        context = ssl.create_default_context(cafile=str(certificate))
        for _ in range(100):
            try:
                with urllib.request.urlopen('https://localhost:4910/api/v1/health', context=context, timeout=2) as response:
                    if response.status == 200:
                        return
            except OSError:
                time.sleep(.2)
        raise RuntimeError('Owned HTTPS API did not become ready')

    def start_api(self):
        args = ['--tmpfs', '/attachments:rw,noexec,nosuid,nodev,uid=65532,gid=65532,mode=700',
                '-v', str(self.work / 'catalog.json') + ':/client-catalog.json:ro']
        for key, value in self.environment.items():
            args.extend(('--env', key + '=' + value))
        self.container('api', self.image, *args)
        self.api = self.owner + '-api'

    def private_configuration(self):
        return {'origin': 'https://localhost:4910/api/v1',
                'ca_pem': (self.work / 'owned-root.crt').read_text(),
                'namespace': 'ru.boohtacord.qa337.' + self.owner.removeprefix('qa337-'),
                'bootstrap_login': 'qa_admin', 'bootstrap_password': self.password,
                'bootstrap': True}
