"""Current delivery fixture, reusing #60 ownership checks and exact cleanup."""
import json
from pathlib import Path
import subprocess
import time
from tools.qa.client_lifecycle.services import local_docker, ports_available
from tools.qa.compatible_rollback.daemon import Daemon as RollbackDaemon
from tools.qa.compatible_rollback.isolation import LABEL, daemon_arguments, require_amd64_daemon, require_owned_daemon


def ssh_packages():
    return ('openssh-server', 'openssh-client', 'sudo')


def mount_arguments(root, work, objects, cache):
    mounts = (str(work)+':/qa', str(objects)+':'+str(objects)+':ro', str(cache)+':/qa-cache',
              str(root/'tools/qa/compatible_rollback')+':/qa-tools:ro',
              str(root/'tools/qa/trusted_delivery')+':/qa-delivery:ro', str(root/'tools')+':/qa-builder/tools:ro')
    return [part for mount in mounts for part in ('-v', mount)]


class Daemon(RollbackDaemon):
    def start(self):
        local_docker()
        require_amd64_daemon(json.loads(self.output('info', '--format', '{{json .}}')))
        ports_available((5443,))
        self.docker('build', '--platform', 'linux/amd64', '--label', LABEL+'='+self.owner,
                    '-t', self.image, str(self.root/'tools/qa/trusted_delivery'))
        self.resources.append(('image', self.image))
        self.docker('volume', 'create', '--label', LABEL+'='+self.owner, self.owner, stdout=subprocess.DEVNULL)
        self.resources.append(('volume', self.owner))
        common = Path(subprocess.check_output(['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'],
                                              cwd=self.root, text=True).strip())
        cache = self.root/'.out/issue395/bundle-cache'
        cache.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.docker('run', '-d', '--name', self.owner, '--label', LABEL+'='+self.owner,
                    '--platform', 'linux/amd64', '--privileged', '--cpus=2', '--memory=4g',
                    '-p', '127.0.0.1:5443:443', '-v', self.owner+':/var/lib/docker',
                    *mount_arguments(self.root, self.work, common/'objects', cache),
                    '--add-host', 'qa60.localhost:127.0.0.1', '-e', 'DOCKER_TLS_CERTDIR=',
                    '-e', 'PYTHONDONTWRITEBYTECODE=1', self.image, *daemon_arguments(self.owner),
                    stdout=subprocess.DEVNULL)
        self.resources.append(('container', self.owner))
        for _ in range(120):
            if self.output('inspect', '--format', '{{.State.Running}}', self.owner) != 'true':
                raise RuntimeError('Owned delivery daemon exited before readiness')
            ready = subprocess.run(['docker', 'exec', self.owner, 'docker', 'info', '--format', '{{json .}}'],
                                   capture_output=True, text=True)
            if ready.returncode == 0:
                require_owned_daemon(json.loads(ready.stdout), self.output('exec', self.owner, 'docker', 'ps', '-aq').splitlines(), self.owner)
                self.execute('python3', '-c', "import socket; assert all(socket.socket().connect_ex(('127.0.0.1',p)) != 0 for p in (2375,2376))")
                (self.work/'owner').write_text(self.owner)
                return
            time.sleep(.5)
        raise RuntimeError('Owned delivery daemon did not become ready')
