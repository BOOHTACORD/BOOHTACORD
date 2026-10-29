"""Owned real SFU transport for independent connection fault acceptance."""
import subprocess
import time

from tools.audio.livekit_fixture import IMAGE
from tools.qa.client_lifecycle.services import local_docker, ports_available
from tools.qa.client_lifecycle.stack import Stack as Base, ready

EGRESS_IMAGE = 'livekit/egress:v1.14.1'
REDIS_IMAGE = 'redis:7.4.12-alpine'


class Stack(Base):
    def start(self):
        local_docker()
        ports_available((4880, 4881, 4882))
        self.preview_root = self.work/'screen-previews'
        self.preview_root.mkdir(parents=True, exist_ok=True)
        self.preview_root.chmod(0o777)
        self.environment['SCREEN_PREVIEW_DIRECTORY'] = '/screen-previews'
        config = self.work/'livekit.yaml'
        config.write_text(f'''port: 4880
bind_addresses: ["0.0.0.0"]
redis:
  address: {self.owner}-redis:6379
rtc:
  tcp_port: 4881
  udp_port: 4882
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
        self.environment['LIVEKIT_PRIVATE_HTTP_URL'] = f'http://{self.owner}-sfu:4880'
        super().start()
        self.container('redis', REDIS_IMAGE,
                       command=('redis-server', '--save', '', '--appendonly', 'no', '--protected-mode', 'no'))
        self.container('sfu', IMAGE,
                       '--publish', '127.0.0.1:4880:4880/tcp',
                       '--publish', '127.0.0.1:4881:4881/tcp',
                       '--publish', '127.0.0.1:4882:4882/udp',
                       '-v', str(config)+':/qa.yaml:ro', network=True,
                       command=('--config', '/qa.yaml'))
        ready('http://127.0.0.1:4880')
        egress_config = self.work/'egress.yaml'
        egress_config.write_text(f'''log_level: info
ws_url: ws://{self.owner}-sfu:4880
insecure: true
health_port: 8080
redis:
  address: {self.owner}-redis:6379
''')
        egress_config.chmod(0o644)
        self.container('egress', EGRESS_IMAGE,
                       '--env', 'EGRESS_CONFIG_FILE=/egress.yaml',
                       '--env', 'LIVEKIT_API_KEY=qa-only',
                       '--env', 'LIVEKIT_API_SECRET=qa-local-only-secret-12345',
                       '-v', str(egress_config)+':/egress.yaml:ro',
                       '-v', str(self.preview_root)+':/screen-previews',
                       memory='2g')
        for _ in range(150):
            logs = subprocess.run(('docker', 'logs', self.owner+'-egress'), capture_output=True, text=True)
            if logs.returncode == 0 and 'service ready' in logs.stdout:
                break
            time.sleep(.2)
        else:
            raise RuntimeError('Owned LiveKit Egress did not become ready')

    def restart(self):
        self.environment['LIVEKIT_PUBLIC_WS_URL'] = 'wss://localhost:4810/qa-sfu'
        super().restart()

    def container(self, role, image, *args, **options):
        if role == 'api':
            args = (*args, '-v', str(self.preview_root)+':/screen-previews')
        if role == 'proxy':
            path = self.work/'Caddyfile'
            path.write_text(path.read_text().replace('  handle /api/* {', '''  handle /qa-sfu* {
    uri strip_prefix /qa-sfu
    reverse_proxy 127.0.0.1:4880
  }
  handle /api/* {'''))
        super().container(role, image, *args, **options)
