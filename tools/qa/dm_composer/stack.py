"""Own one isolated database, Tempo, proxy and Linux API container."""
import secrets
import hashlib
import json
import shutil
import ssl
import subprocess
import time
import urllib.request
from pathlib import Path
from tools.qa.client_lifecycle.services import LABEL, TEMPO, caddy_config, local_docker, ports_available, remove_owned, run


def ready(url):
    for _ in range(150):
        try:
            context = ssl._create_unverified_context() if url.startswith('https://localhost:4940/') else None
            with urllib.request.urlopen(url, timeout=1, context=context) as response:
                if response.status == 200:
                    return
        except (OSError, urllib.error.HTTPError):
            time.sleep(.2)
    raise RuntimeError('Disposable service did not become ready')


class BaseStack:
    def __init__(self, root, work):
        self.root, self.work = root, work
        self.owner = 'qa294-'+secrets.token_hex(8)
        self.resources, self.api = [], None
        self.image = self.owner+'-api'
        self.password = secrets.token_urlsafe(24)
        self.environment = {
            'DATABASE_URL': f'postgres://qa:qa-disposable-only@{self.owner}-db:5432/qa?sslmode=disable',
            'API_ADDR': '0.0.0.0:8080',
            'PUBLIC_ORIGIN': 'https://localhost:4940',
            'ATTACHMENTS_DIRECTORY': '/attachments',
            'LIVEKIT_API_KEY': 'qa-only',
            'LIVEKIT_API_SECRET': 'qa-local-only-secret-12345',
            'LIVEKIT_PUBLIC_WS_URL': 'ws://localhost:4992',
            'LIVEKIT_PRIVATE_HTTP_URL': 'http://host.docker.internal:4992',
            'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT': f'http://{self.owner}-tempo:4318/v1/traces',
        }

    def container(self, role, image, *args, network=True, command=()):
        name = self.owner+'-'+role
        run('docker', 'run', '-d', '--name', name, '--label', LABEL+'='+self.owner,
            '--cpus=2', '--memory=1g', '--network', self.owner if network else 'host',
            *args, image, *command, stdout=subprocess.DEVNULL)
        self.resources.append(('container', name))

    def start(self):
        local_docker()
        ports_available((4940, 4942, 4943))
        run('docker', 'network', 'create', '--label', LABEL+'='+self.owner,
            self.owner, stdout=subprocess.DEVNULL)
        self.resources.append(('network', self.owner))
        self.container('db', 'postgres:17.6-alpine', '--tmpfs', '/var/lib/postgresql/data',
                       '-e', 'POSTGRES_DB=qa', '-e', 'POSTGRES_USER=qa',
                       '-e', 'POSTGRES_PASSWORD=qa-disposable-only')
        (self.work/'tempo.yaml').write_text(TEMPO)
        (self.work/'tempo.yaml').chmod(0o644)
        self.container('tempo', 'grafana/tempo:2.10.3', '--publish', '127.0.0.1:4942:3200',
                       '--tmpfs', '/tmp:mode=1777',
                       '-v', str(self.work/'tempo.yaml')+':/etc/tempo.yaml:ro',
                       command=('-config.file=/etc/tempo.yaml',))
        run('docker', 'exec', self.owner+'-db', 'sh', '-c',
            'until pg_isready -U qa -d qa; do sleep .2; done', stdout=subprocess.DEVNULL)
        ready('http://127.0.0.1:4942/ready')
        backend = self.root/'backend'
        def source_manifest(directory):
            return {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in sorted(directory.rglob('*')) if p.is_file()}
        selected = source_manifest(backend)
        frozen_backend = self.work/'backend-source'
        shutil.copytree(backend, frozen_backend)
        if source_manifest(frozen_backend) != selected or source_manifest(backend) != selected:
            raise ValueError('Backend source changed while snapshotting')
        self.backend_source_manifest_sha256 = hashlib.sha256(json.dumps(selected, sort_keys=True).encode()).hexdigest()
        run('docker', 'build', '--label', LABEL+'='+self.owner, '--tag', self.image,
            '--file', str(frozen_backend/'Dockerfile'), str(frozen_backend),
            stdout=subprocess.DEVNULL)
        self.resources.append(('image', self.image))
        self.backend_image_id = subprocess.check_output(['docker', 'inspect', '--format', '{{.Id}}', self.image], text=True).strip()
        self.migrate()
        self.bootstrap()
        self.seed_admin_members()
        self.restart()
        (self.work/'Caddyfile').write_text(caddy_config(self.root).replace('4810','4940').replace('4820','4943').replace(str(self.root/'clients/web/dist'), str(self.root/'.out/qa294-build')).replace('bind 127.0.0.1','bind 0.0.0.0').replace('127.0.0.1:4943', self.owner+'-api:8080'))
        self.container('proxy', 'caddy:2.10.0-alpine', '--publish', '127.0.0.1:4940:4940', '-v', str(self.root)+':'+str(self.root)+':ro',
                       '-v', str(self.work/'Caddyfile')+':/etc/caddy/Caddyfile:ro', network=True)
        ready('https://localhost:4940/api/v1/health')

    def migrate(self):
        run('docker', 'run', '--rm', '--network', self.owner, '--label', LABEL+'='+self.owner,
            '--env', 'DATABASE_URL='+self.environment['DATABASE_URL'], '--entrypoint', '/migrate',
            self.image, stdout=subprocess.DEVNULL)

    def bootstrap(self):
        run('docker', 'run', '-i', '--rm', '--network', self.owner, '--label', LABEL+'='+self.owner,
            '--env', 'DATABASE_URL='+self.environment['DATABASE_URL'], '--entrypoint', '/bootstrap-admin',
            self.image, '--login', 'qa_admin', '--password-stdin', input=self.password+'\n',
            text=True, stdout=subprocess.DEVNULL)

    def seed_admin_members(self):
        sql = """INSERT INTO users (id, login, display_name, password_hash, role)
SELECT gen_random_uuid(),
       'qa_member_' || lpad(member_index::text, 2, '0'),
       'Участник ' || lpad(member_index::text, 2, '0'),
       'qa-screenshot-fixture-disabled',
       'MEMBER'
FROM generate_series(1, 19) AS member_index;"""
        run('docker', 'exec', self.owner+'-db', 'psql', '-U', 'qa', '-d', 'qa',
            '-v', 'ON_ERROR_STOP=1', '-c', sql, stdout=subprocess.DEVNULL)

    def start_api(self):
        arguments = [
            '--publish', '127.0.0.1:4943:8080',
            '--add-host', 'host.docker.internal:host-gateway',
            '--tmpfs', '/attachments:rw,noexec,nosuid,nodev,uid=65532,gid=65532,mode=700',
        ]
        for key, value in self.environment.items():
            arguments.extend(('--env', key+'='+value))
        self.container('api', self.image, *arguments)
        self.api = self.owner+'-api'
        ready('http://127.0.0.1:4943/api/v1/health')

    def restart(self):
        self.stop_api()
        self.start_api()

    def stop_api(self):
        if self.api:
            remove_owned(self.api, self.owner, 'container')
            self.resources.remove(('container', self.api))
            self.api = None

    def close(self):
        self.stop_api()
        for kind, name in reversed(self.resources):
            remove_owned(name, self.owner, kind)
        self.resources.clear()


class Stack(BaseStack):
    def start(self):
        from tools.audio.livekit_fixture import IMAGE
        ports_available((4992,4993,4994))
        config=self.work/'livekit.yaml'
        config.write_text(f'''port: 4880
bind_addresses: ["0.0.0.0"]
rtc:
  tcp_port: 4993
  udp_port: 4994
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
        config.chmod(0o644)
        self.environment['LIVEKIT_PRIVATE_HTTP_URL']=f'http://{self.owner}-sfu:4880'
        self.environment['LIVEKIT_PUBLIC_WS_URL']='wss://localhost:4940/qa-sfu'
        super().start()
        self.container('sfu',IMAGE,'--publish','127.0.0.1:4992:4880/tcp',
                       '--publish','127.0.0.1:4993:4993/tcp','--publish','127.0.0.1:4994:4994/udp',
                       '-v',str(config)+':/qa.yaml:ro',command=('--config','/qa.yaml','--node-ip','127.0.0.1'))
        ready('http://127.0.0.1:4992')

    def container(self,role,image,*args,**options):
        if role=='proxy':
            path=self.work/'Caddyfile'
            path.write_text(path.read_text().replace('  handle /api/* {',f'''  handle /qa-sfu* {{
    uri strip_prefix /qa-sfu
    reverse_proxy {self.owner}-sfu:4880
  }}
  handle /api/* {{'''))
        return super().container(role,image,*args,**options)
