"""Owned R2 fault gate; the existing R1 fixture configuration remains default."""
import secrets
import subprocess
import ssl
import time
import urllib.request
from tools.qa.client_lifecycle.services import LABEL, run, read_only_directory_mount
from tools.qa.realtime_recovery.native.stack import Stack as Base


class Stack(Base):
    def __init__(self, *args, web=False):
        super().__init__(*args)
        self.web = web
        self.fault_token = secrets.token_hex(32)

    def container(self, role, image, *args, **options):
        if role == 'proxy' and self.web:
            args = (*args, *read_only_directory_mount(self.root/'clients/web/dist', '/qa-web'))
        super().container(role, image, *args, **options)

    def start(self):
        super().start()
        image = self.owner+'-fault-image'
        run('docker', 'build', '--label', LABEL+'='+self.owner, '--tag', image,
            str(self.root/'tools/qa/realtime_connect/faults'), stdout=subprocess.DEVNULL)
        self.resources.append(('image', image))
        self.container('fault', image, '-e', 'R2_CONTROL_TOKEN='+self.fault_token,
                       '-e', 'R2_UPSTREAM=http://'+self.owner+'-api:8080')
        request = urllib.request.Request('https://localhost:4910/qa-r2/control',
            headers={'Authorization': 'Bearer '+self.fault_token})
        for _ in range(50):
            try:
                with urllib.request.urlopen(request, timeout=2,
                        context=ssl._create_unverified_context()) as response:
                    if response.status == 200: return
            except OSError:
                time.sleep(.1)
        raise RuntimeError('Owned R2 gate did not become ready')

    def proxy_config(self):
        config = super().proxy_config().replace(' handle /api/* {', '''
 @r2 path /api/v1/realtime /api/v1/public/realtime /api/v1/auth/session /qa-r2/control
 handle @r2 {
  reverse_proxy '''+self.owner+'''-fault:8081
 }
 handle /api/* {''')
        if self.web:
            prefix, suffix = config.rsplit('\n}', 1)
            config = prefix+'\n handle {\n  root * /qa-web\n  try_files {path} /index.html\n  file_server\n }\n}'+suffix
        return config
