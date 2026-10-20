"""Finite Docker metadata only; command output never enters the public report."""
import hashlib
import json
import os
import re
import subprocess
import tempfile
from .storage_lease import require

LABEL = 'org.boohtacord.builder.owner'
SCOPE = 'org.boohtacord.builder.scope'
IMAGE_FORMAT = ('{"id":{{json .Id}},"owner":{{json (index .Config.Labels "'+LABEL+'")}},'
    '"revision":{{json (index .Config.Labels "org.opencontainers.image.revision")}},'
    '"archive":{{json (index .Config.Labels "org.voice-platform.source-archive-sha256")}},'
    '"tags":{{json .RepoTags}},"digests":{{json .RepoDigests}}}')


class DockerCommandError(ValueError):
    """Safe finite diagnostics for metrics and the public exception message."""
    def __init__(self, operation, reason):
        operations = {'daemon_info', 'image_list', 'resource_command'}
        reasons = {'timeout', 'exit_status', 'output_limit', 'encoding', 'os_error'}
        require(operation in operations and reason in reasons)
        self.operation, self.reason = operation, reason
        super().__init__('Builder Docker '+operation+': '+reason)


class Docker:
    def __init__(self, environment):
        self.environment = environment
        require(not environment.get('DOCKER_CONTEXT') or environment['DOCKER_CONTEXT'] == 'default')
        require(not environment.get('DOCKER_HOST') or environment['DOCKER_HOST'].startswith('unix://'))

    def command(self, *args, timeout=30):
        operation = ('daemon_info' if args[:1] == ('info',) else
                     'image_list' if args[:2] == ('image', 'ls') else 'resource_command')
        with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
            try:
                result = subprocess.run(['docker', *args], env=self.environment, stdout=stdout,
                                        stderr=stderr, timeout=timeout)
                if result.returncode != 0:
                    raise DockerCommandError(operation, 'exit_status')
                if stdout.tell() > 1_000_000 or stderr.tell() > 1_000_000:
                    raise DockerCommandError(operation, 'output_limit')
                stdout.seek(0)
                return stdout.read().decode('utf-8').strip()
            except subprocess.TimeoutExpired:
                raise DockerCommandError(operation, 'timeout') from None
            except UnicodeError:
                raise DockerCommandError(operation, 'encoding') from None
            except OSError:
                raise DockerCommandError(operation, 'os_error') from None

    def snapshot(self):
        info = json.loads(self.command('info', '--format', '{"id":{{json .ID}},"root":{{json .DockerRootDir}}}'))
        require(isinstance(info['id'], str) and 0 < len(info['id']) <= 200
                and isinstance(info['root'], str) and info['root'].startswith('/'))
        filesystem = os.statvfs(info['root'])
        images = self.command('image', 'ls', '--all', '--quiet', '--no-trunc').splitlines()
        require(len(images) <= 20000 and all(re.fullmatch('sha256:[0-9a-f]{64}', value) for value in images))
        return dict(daemon_sha256=hashlib.sha256(info['id'].encode()).hexdigest(),
                    filesystem_available_bytes=filesystem.f_bavail*filesystem.f_frsize,
                    filesystem_used_bytes=(filesystem.f_blocks-filesystem.f_bfree)*filesystem.f_frsize,
                    image_count=len(set(images)))

    def volume(self, name):
        names = self.command('volume', 'ls', '--filter', 'name='+name, '--format', '{{.Name}}').splitlines()
        if name not in names:
            return None
        return dict(owner=json.loads(self.command('volume', 'inspect', '--format',
            '{{json (index .Labels "'+LABEL+'")}}', name)))

    def container(self, name):
        identities = self.command('container', 'ls', '--all', '--filter', 'name=^/'+name+'$',
                                  '--no-trunc', '--format', '{{.ID}}').splitlines()
        require(len(identities) <= 1)
        if not identities:
            return None
        require(re.fullmatch('[0-9a-f]{64}', identities[0]))
        row = json.loads(self.command('container', 'inspect', '--format',
            '{"id":{{json .Id}},"image":{{json .Config.Image}},"mounts":{{json .Mounts}}}', identities[0]))
        row['mounts'] = [dict(type=m['Type'], name=m.get('Name'), destination=m['Destination']) for m in row['mounts']]
        return row

    def create_volume(self, name, owner):
        require(self.command('volume', 'create', '--label', LABEL+'='+owner, name) == name)

    def create_builder(self, name, image, config):
        self.command('buildx', 'create', '--name', name, '--node', name+'0', '--driver', 'docker-container',
                     '--driver-opt', 'image='+image, '--buildkitd-config', str(config), timeout=60)
        self.command('buildx', 'inspect', '--bootstrap', name, timeout=180)

    def image(self, identity):
        row = json.loads(self.command('image', 'inspect', '--format', IMAGE_FORMAT, identity))
        row['tags'] = row['tags'] or []
        row['digests'] = row['digests'] or []
        return row

    def matching_images(self, owner):
        identities = self.command('image', 'ls', '--all', '--no-trunc', '--quiet', '--filter',
                                  'label='+LABEL+'='+owner).splitlines()
        require(len(identities) <= 16)
        return [self.image(value) for value in sorted(set(identities))]

    def tag_image(self, tag):
        identities = self.command('image', 'ls', '--all', '--no-trunc', '--quiet', '--filter',
                                  'reference='+tag).splitlines()
        require(len(identities) <= 1)
        return self.image(identities[0]) if identities else None

    def image_users(self, identity):
        rows=self.command('container','ls','--all','--no-trunc','--filter','ancestor='+identity,'--quiet').splitlines()
        require(len(rows)<=100 and all(re.fullmatch('[0-9a-f]{64}',value) for value in rows))
        return rows

    def smoke_resources(self, owner):
        result={'containers':[],'networks':[]}
        for kind in ('container','network'):
            args=[kind,'ls',*(['--all','--no-trunc'] if kind=='container' else ['--no-trunc']),
                  '--filter','label='+LABEL+'='+owner,'--format','{{.ID}}']
            identities=self.command(*args).splitlines()
            require(len(identities)<=100 and all(re.fullmatch('[0-9a-f]{64}',value) for value in identities))
            for identity in identities:
                common='"id":{{json .Id}},"owner":{{json (index .'+('Config.Labels' if kind=='container' else 'Labels')+' "'+LABEL+'")}},'
                common+='"scope":{{json (index .'+('Config.Labels' if kind=='container' else 'Labels')+' "'+SCOPE+'")}}'
                extra=',"privileged":{{json .HostConfig.Privileged}},"mounts":{{json .Mounts}}' if kind=='container' else ',"name":{{json .Name}},"containers":{{json .Containers}}'
                row=json.loads(self.command(kind,'inspect','--format','{'+common+extra+'}',identity))
                if kind=='container':row['mount_types']=[m['Type'] for m in row.pop('mounts')]
                else:row['users']=list((row.pop('containers') or {}).keys())
                result['containers' if kind=='container' else 'networks'].append(row)
        return result

    def remove_container(self, identity):
        self.command('container', 'rm', '--force', '--volumes', identity)

    def remove_network(self, identity):
        self.command('network','rm',identity)

    def remove_volume(self, name):
        self.command('volume', 'rm', name)

    def remove_image(self, identity):
        self.command('image', 'rm', '--no-prune', identity)
