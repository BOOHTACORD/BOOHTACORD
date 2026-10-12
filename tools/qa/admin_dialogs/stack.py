"""Own one isolated database, Tempo, proxy and Linux API container."""
from dataclasses import dataclass
import secrets
import shutil
import hashlib
import json
import ssl
import subprocess
import time
import urllib.request
from pathlib import Path
from .policy import cleanup_resources
from tools.qa.client_lifecycle.services import LABEL, TEMPO, caddy_config, local_docker, ports_available, remove_owned, run


@dataclass(frozen=True)
class Ports:
    https: int
    api: int
    tempo: int
    sfu_http: int
    sfu_tcp: int
    sfu_udp: int

NATIVE_PORTS=Ports(4950,4951,4952,4990,4991,4995)
WEB_PORTS=Ports(4960,4961,4962,4996,4997,4999)

def proxy_config(root,owner,*,dist=None,ports=NATIVE_PORTS):
    return caddy_config(root).replace(str(root/'clients/web/dist'),str(dist or root/'clients/web/dist')).replace('4810',str(ports.https)).replace('4820',str(ports.api)).replace('bind 127.0.0.1','bind 0.0.0.0').replace(f'127.0.0.1:{ports.api}',owner+'-api:8080')


def ready(url):
    for _ in range(150):
        try:
            context = ssl._create_unverified_context() if url.startswith('https://localhost:') else None
            with urllib.request.urlopen(url, timeout=1, context=context) as response:
                if response.status == 200:
                    return
        except (OSError, urllib.error.HTTPError):
            time.sleep(.2)
    raise RuntimeError('Disposable service did not become ready')


class BaseStack:
    def __init__(self, root, work, *, ports=NATIVE_PORTS):
        if ports not in (NATIVE_PORTS,WEB_PORTS):raise ValueError('Unassigned QA ports')
        self.ports=ports
        self.root, self.work = root, work
        self.owner = 'qa295298-'+secrets.token_hex(8)
        self.resources, self.api = [], None
        self.image = self.owner+'-api'
        self.password = secrets.token_urlsafe(24)
        self.environment = {
            'DATABASE_URL': f'postgres://qa:qa-disposable-only@{self.owner}-db:5432/qa?sslmode=disable',
            'API_ADDR': '0.0.0.0:8080',
            'PUBLIC_ORIGIN': f'https://localhost:{ports.https}',
            'ATTACHMENTS_DIRECTORY': '/attachments',
            'LIVEKIT_API_KEY': 'qa-only',
            'LIVEKIT_API_SECRET': 'qa-local-only-secret-12345',
            'LIVEKIT_PUBLIC_WS_URL': f'ws://localhost:{ports.sfu_http}',
            'LIVEKIT_PRIVATE_HTTP_URL': f'http://host.docker.internal:{ports.sfu_http}',
            'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT': f'http://{self.owner}-tempo:4318/v1/traces',
        }

    def container(self, role, image, *args, network=True, command=()):
        name = self.owner+'-'+role
        run('docker', 'run', '-d', '--name', name, '--label', LABEL+'='+self.owner,
            '--cpus=2', '--memory=1g', '--network', self.owner if network else 'host',
            *args, image, *command, stdout=subprocess.DEVNULL)
        self.resources.append(('container', name))

    def start(self):
        def artifact_manifest(directory):
            return {str(p.relative_to(directory)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(directory.rglob('*')) if p.is_file()}
        current=self.root/'clients/web/dist'
        before=artifact_manifest(current)
        if not before:raise ValueError('Current production Web artifact is missing')
        self.dist=self.work/'web-dist'
        shutil.copytree(current,self.dist)
        if before!=artifact_manifest(current) or before!=artifact_manifest(self.dist):raise ValueError('Shared Web build changed during isolation')
        self.web_artifact_sha256=hashlib.sha256(json.dumps(before,sort_keys=True).encode()).hexdigest()
        local_docker()
        ports_available((self.ports.https,self.ports.tempo,self.ports.api))
        run('docker', 'network', 'create', '--label', LABEL+'='+self.owner,
            self.owner, stdout=subprocess.DEVNULL)
        self.resources.append(('network', self.owner))
        self.container('db', 'postgres:17.6-alpine', '--tmpfs', '/var/lib/postgresql/data',
                       '-e', 'POSTGRES_DB=qa', '-e', 'POSTGRES_USER=qa',
                       '-e', 'POSTGRES_PASSWORD=qa-disposable-only')
        (self.work/'tempo.yaml').write_text(TEMPO)
        (self.work/'tempo.yaml').chmod(0o644)
        self.container('tempo', 'grafana/tempo:2.10.3', '--publish', f'127.0.0.1:{self.ports.tempo}:3200',
                       '--tmpfs', '/tmp:mode=1777',
                       '-v', str(self.work/'tempo.yaml')+':/etc/tempo.yaml:ro',
                       command=('-config.file=/etc/tempo.yaml',))
        run('docker', 'exec', self.owner+'-db', 'sh', '-c',
            'until pg_isready -U qa -d qa; do sleep .2; done', stdout=subprocess.DEVNULL)
        ready(f'http://127.0.0.1:{self.ports.tempo}/ready')
        run('docker', 'build', '--label', LABEL+'='+self.owner, '--tag', self.image,
            '--file', str(self.root/'backend/Dockerfile'), str(self.root/'backend'),
            stdout=subprocess.DEVNULL)
        self.resources.append(('image', self.image))
        self.migrate()
        self.bootstrap()
        self.seed_admin_members()
        self.restart()
        (self.work/'Caddyfile').write_text(proxy_config(self.root,self.owner,dist=self.dist,ports=self.ports))
        self.container('proxy', 'caddy:2.10.0-alpine', '--publish', f'127.0.0.1:{self.ports.https}:{self.ports.https}', '-v', str(self.root)+':'+str(self.root)+':ro',
                       '-v', str(self.work/'Caddyfile')+':/etc/caddy/Caddyfile:ro', network=True)
        ready(f'https://localhost:{self.ports.https}/api/v1/health')

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
            '--publish', f'127.0.0.1:{self.ports.api}:8080',
            '--add-host', 'host.docker.internal:host-gateway',
            '--tmpfs', '/attachments:rw,noexec,nosuid,nodev,uid=65532,gid=65532,mode=700',
        ]
        for key, value in self.environment.items():
            arguments.extend(('--env', key+'='+value))
        self.container('api', self.image, *arguments)
        self.api = self.owner+'-api'
        ready(f'http://127.0.0.1:{self.ports.api}/api/v1/health')

    def restart(self):
        self.stop_api()
        self.start_api()

    def stop_api(self):
        if self.api:
            remove_owned(self.api, self.owner, 'container')
            self.resources.remove(('container', self.api))
            self.api = None

    def close(self):
        errors=cleanup_resources(self.resources,self.owner)
        self.api=None if ('container',self.api) not in self.resources else self.api
        if errors:raise RuntimeError('Owned cleanup did not complete: '+str([e['error_type'] for e in errors]))


class Stack(BaseStack):
    def start(self):
        from tools.audio.livekit_fixture import IMAGE
        ports_available((self.ports.sfu_http,self.ports.sfu_tcp,self.ports.sfu_udp))
        config=self.work/'livekit.yaml'
        config.write_text(f'''port: {self.ports.sfu_http}
bind_addresses: ["0.0.0.0"]
rtc:
  tcp_port: {self.ports.sfu_tcp}
  udp_port: {self.ports.sfu_udp}
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
        self.environment['LIVEKIT_PRIVATE_HTTP_URL']=f'http://{self.owner}-sfu:{self.ports.sfu_http}'
        self.environment['LIVEKIT_PUBLIC_WS_URL']=f'wss://localhost:{self.ports.https}/qa-sfu'
        super().start()
        self.container('sfu',IMAGE,'--publish',f'127.0.0.1:{self.ports.sfu_http}:{self.ports.sfu_http}/tcp',
                       '--publish',f'127.0.0.1:{self.ports.sfu_tcp}:{self.ports.sfu_tcp}/tcp','--publish',f'127.0.0.1:{self.ports.sfu_udp}:{self.ports.sfu_udp}/udp',
                       '-v',str(config)+':/qa.yaml:ro',command=('--config','/qa.yaml','--node-ip','127.0.0.1'))
        ready(f'http://127.0.0.1:{self.ports.sfu_http}')

    def container(self,role,image,*args,**options):
        if role=='proxy':
            path=self.work/'Caddyfile'
            path.write_text(path.read_text().replace('  handle /api/* {',f'''  handle /qa-sfu* {{
    uri strip_prefix /qa-sfu
    reverse_proxy {self.owner}-sfu:{self.ports.sfu_http}
  }}
  handle /api/* {{'''))
        return super().container(role,image,*args,**options)
