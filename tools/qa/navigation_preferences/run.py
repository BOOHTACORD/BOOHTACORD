"""Acceptance for #251: two origins on one disposable guild, never production."""
import hashlib
import json
import os
import subprocess
import tempfile
import ssl
import time
import urllib.request
from pathlib import Path
from tools.qa.local_features.stack import Stack as Base
from tools.qa.client_lifecycle.stack import Stack as Containers, ready
from tools.qa.client_lifecycle.services import ports_available


class Stack(Base):
    def start(self):
        ports_available((4811,))
        super().start()
        arguments = ['--tmpfs', '/attachments:rw,noexec,nosuid,nodev,uid=65532,gid=65532,mode=700', '--add-host', 'host.docker.internal:host-gateway']
        for key, value in dict(self.environment, PUBLIC_ORIGIN='https://localhost:4811').items():
            arguments += ['--env', key+'='+value]
        self.container('second-api', self.image, *arguments)
        for _ in range(150):
            try:
                with urllib.request.urlopen('https://localhost:4811/api/v1/health', context=ssl._create_unverified_context(), timeout=1) as response:
                    if response.status == 200:
                        break
            except OSError:
                time.sleep(.2)
        else:
            raise RuntimeError('Owned second localhost origin did not become ready')

    def container(self, role, image, *args, **options):
        if role != 'proxy':
            return super().container(role, image, *args, **options)
        configuration = '{\n admin off\n auto_https disable_redirects\n}\n'
        for port, api in [(4810, 'api'), (4811, 'second-api')]:
            configuration += f'''https://localhost:{port} {{
 bind 0.0.0.0
 tls internal
 handle /qa-sfu* {{
  uri strip_prefix /qa-sfu
  reverse_proxy {self.owner}-sfu:4880
 }}
 handle /api/* {{
  reverse_proxy {self.owner}-{api}:8080
 }}
 handle {{
  root * "{self.root}/clients/web/dist"
  try_files {{path}} /index.html
  file_server
 }}
}}
'''
        (self.work/'Caddyfile').write_text(configuration)
        options['network'] = True
        return Containers.container(self, role, image, '--publish', '127.0.0.1:4810:4810', '--publish', '127.0.0.1:4811:4811', *args, **options)


def main():
    root = Path(__file__).resolve().parents[3]
    destination = root/'.out/qa251-20261012'
    destination.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, DOCKER_CONTEXT='colima-boohtacord-qa', VITE_PUBLIC_ORIGIN='https://localhost:4810')
    os.environ.update(DOCKER_CONTEXT=env['DOCKER_CONTEXT'])
    subprocess.run(['npm', 'run', 'build'], cwd=root/'clients/web', env=env, check=True, stdout=subprocess.DEVNULL)
    for width in [1440, 393]:
        directory = destination/str(width)
        directory.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='qa251-', dir=root/'.out') as temporary:
            work = Path(temporary)
            stack = Stack(root, work)
            try:
                stack.start()
                inputs = work/'input.json'
                inputs.write_text(json.dumps({'password':stack.password, 'width':width, 'directory':str(directory)}))
                inputs.chmod(0o600)
                env.update(QA_ORIGIN='https://localhost:4810', QA_INPUT=str(inputs), QA_RESULT=str(directory/'results.json'))
                subprocess.run(['node', str(root/'tools/qa/navigation_preferences/scenario.mjs')], cwd=root, env=env, check=True, timeout=300)
            finally:
                stack.close()
        report = json.loads((directory/'results.json').read_text())
        report.update(candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(), owned_resources_removed=True,
                      screenshots={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.glob('*.png')})
        (directory/'results.json').write_text(json.dumps(report,indent=2)+'\n')
        print(f'#251 width {width}: PASS, owned services removed', flush=True)


if __name__ == '__main__':
    main()
