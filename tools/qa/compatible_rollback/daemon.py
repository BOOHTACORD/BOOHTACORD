"""One owned nested daemon; never expose its socket or touch foreign projects."""
import json
import os
from pathlib import Path
import secrets
import subprocess
import time
from tools.qa.client_lifecycle.services import local_docker, ports_available
from .isolation import LABEL, require_owner, require_owned_daemon, daemon_arguments, require_amd64_daemon, ownership_arguments


class Daemon:
    def __init__(self, root, work):
        self.root, self.work = root, work
        self.owner = 'qa60-' + secrets.token_hex(8)
        self.image = self.owner + '-controller'
        self.resources = []

    def docker(self, *args, **kwargs):
        return subprocess.run(['docker', *args], check=True, **kwargs)

    def output(self, *args):
        return subprocess.check_output(['docker', *args], text=True).strip()

    def start(self):
        local_docker()
        require_amd64_daemon(json.loads(self.output('info', '--format', '{{json .}}')))
        ports_available((5443,))
        self.docker('build', '--platform', 'linux/amd64', '--label', LABEL + '=' + self.owner,
                    '-t', self.image, str(self.root / 'tools/qa/compatible_rollback'))
        self.resources.append(('image', self.image))
        self.docker('volume', 'create', '--label', LABEL + '=' + self.owner, self.owner, stdout=subprocess.DEVNULL)
        self.resources.append(('volume', self.owner))
        common = Path(subprocess.check_output(
            ['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'], cwd=self.root, text=True).strip())
        cache = self.root / '.out/issue60/bundle-cache'
        cache.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.docker('run', '-d', '--name', self.owner, '--label', LABEL + '=' + self.owner,
                    '--platform', 'linux/amd64', '--privileged', '--cpus=2', '--memory=4g',
                    '-p', '127.0.0.1:5443:443', '-v', self.owner + ':/var/lib/docker',
                    '-v', str(self.work) + ':/qa', '-v', str(common / 'objects') + ':' + str(common / 'objects') + ':ro',
                    '-v', str(cache) + ':/qa-cache',
                    '-v', str(self.root / 'tools/qa/compatible_rollback') + ':/qa-tools:ro',
                    '--add-host', 'qa60.localhost:127.0.0.1', '-e', 'DOCKER_TLS_CERTDIR=',
                    self.image, *daemon_arguments(self.owner),
                    stdout=subprocess.DEVNULL)
        self.resources.append(('container', self.owner))
        for _ in range(120):
            if self.output('inspect', '--format', '{{.State.Running}}', self.owner) != 'true':
                raise RuntimeError('Owned nested daemon exited before readiness')
            ready = subprocess.run(['docker', 'exec', self.owner, 'docker', 'info', '--format', '{{json .}}'], capture_output=True, text=True)
            if ready.returncode == 0:
                objects = self.output('exec', self.owner, 'docker', 'ps', '-aq').splitlines()
                require_owned_daemon(json.loads(ready.stdout), objects, self.owner)
                self.execute('python3', '-c',
                             "import socket; assert all(socket.socket().connect_ex(('127.0.0.1',p)) != 0 for p in (2375,2376))")
                (self.work / 'owner').write_text(self.owner)
                return
            time.sleep(.5)
        raise RuntimeError('Owned nested daemon did not become ready')

    def execute(self, *args, **kwargs):
        return self.docker('exec', '-w', '/qa', self.owner, *args, **kwargs)

    def reclaim(self):
        require_owner(json.loads(self.output('inspect', '--format', '{{json .Config.Labels}}', self.owner)), self.owner)
        arguments = ownership_arguments(os.getuid(), os.getgid(), [p.name for p in self.work.iterdir()])
        if arguments:
            self.execute(*arguments, stdout=subprocess.DEVNULL, timeout=120)

    def close(self):
        for kind, name in reversed(self.resources):
            command = ['image', 'inspect'] if kind == 'image' else [kind, 'inspect'] if kind == 'volume' else ['inspect']
            result = self.output(*command, '--format', '{{json .Config.Labels}}' if kind in ('container', 'image') else '{{json .Labels}}', name)
            require_owner(json.loads(result) or {}, self.owner)
            if kind == 'container' and self.output('inspect', '--format', '{{.State.Running}}', name) == 'true':
                self.reclaim()
            self.docker(*( ['rm', '-f', '-v'] if kind == 'container' else [kind, 'rm']), name, stdout=subprocess.DEVNULL)
        self.resources.clear()
