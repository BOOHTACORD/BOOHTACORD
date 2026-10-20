"""One owned BuildKit daemon per build; recover interrupted cleanup under a lease."""
import json
import hashlib
from pathlib import Path
import re
import signal
import time
import uuid
from .storage_docker import Docker
from .storage_lease import Lease, require

CONFIG = '''[worker.oci]
  gc = true
  reservedSpace = 0
  maxUsedSpace = 8589934592
  minFreeSpace = 2147483648
[[worker.oci.gcpolicy]]
  all = true
  reservedSpace = 0
  maxUsedSpace = 8589934592
  minFreeSpace = 2147483648
[worker.containerd]
  enabled = false
'''


def names(owner):
    builder = 'boohtacord-server-'+owner
    container = 'buildx_buildkit_'+builder+'0'
    return builder, container, container+'_state'


class BuilderStorage:
    def __init__(self, root, environment, revision, archive, *, lease_root=None, docker=None):
        require(re.fullmatch('[0-9a-f]{40}', revision) and re.fullmatch('[0-9a-f]{64}', archive))
        self.root = Path(root)
        self.environment = dict(environment)
        self.revision, self.archive = revision, archive
        self.docker = docker or Docker(environment)
        self.lease = Lease(lease_root or Path.home()/'.cache/boohtacord-builder-storage-v1')
        self.state = None
        self.old_signal = None
        self.active = False
        self.report = dict(schema_version=1, status='RUNNING', owned_resources_removed=False,
                           recovered_previous_lease=False, removed_image_count=0)

    def __enter__(self):
        started = time.monotonic()
        policy_bytes = (self.root/'tools/build/server/buildkit-image.json').read_bytes()
        policy = json.loads(policy_bytes)
        require(set(policy) == {'schema_version','version','image'} and type(policy['schema_version']) is int
                and policy['schema_version'] == 1 and isinstance(policy['version'],str)
                and re.fullmatch('[0-9]+\\.[0-9]+\\.[0-9]+',policy['version']))
        image = policy['image']
        require(isinstance(image, str) and re.fullmatch(r'moby/buildkit@sha256:[0-9a-f]{64}', image))
        self.lease.__enter__()
        self.active = True
        try:
            self.old_signal = signal.signal(signal.SIGTERM, self.terminate)
            before = self.docker.snapshot()
            self.report['filesystem_before'] = before
            previous = self.lease.read()
            if previous:
                self.cleanup(previous)
                self.lease.clear()
                self.report['recovered_previous_lease'] = True
            capacity=self.docker.snapshot() if previous else before
            require(capacity['daemon_sha256']==before['daemon_sha256'])
            if previous:self.report['post_recovery_filesystem']=capacity
            # Do not replace an existing target, including legacy images without
            # a journal. Same-source delivery retries reuse their verified producer.
            for service in ('api', 'web'):
                require(self.docker.tag_image('voice-platform-'+service+':'+self.revision) is None)
            require(capacity['filesystem_available_bytes'] >= 14*1024**3)
            owner = uuid.uuid4().hex
            self.state = dict(owner=owner, image=image, revision=self.revision, archive=self.archive,
                              daemon_sha256=before['daemon_sha256'])
            builder, container, volume = names(owner)
            require(self.docker.container(container) is None and self.docker.volume(volume) is None)
            require(not self.docker.matching_images(owner))
            self.lease.save(self.state)
            self.docker.create_volume(volume, owner)
            require(self.docker.volume(volume) == dict(owner=owner))
            config = Path(self.environment['DOCKER_CONFIG'])/('buildkitd-'+owner+'.toml')
            require(config.parent.is_dir() and not config.exists())
            config.write_text(CONFIG)
            self.docker.create_builder(builder, image, config)
            container_row, volume_row = self.validate_backend(self.state)
            require(container_row and volume_row)
            self.environment.update(BUILDX_BUILDER=builder, BOOHTACORD_BUILD_OWNER=owner)
            self.report.update(buildkit_image=image, buildkit_policy_sha256=hashlib.sha256(policy_bytes).hexdigest(),
                               transient_gc_target_bytes=8*1024**3,
                               gc_target_is_write_quota=False, setup_seconds=round(time.monotonic()-started,6))
            return self
        except BaseException:
            self.finish(failed=True)
            raise

    @staticmethod
    def terminate(*_):
        raise InterruptedError('Owned builder interrupted')

    def validate_backend(self, state):
        require(self.docker.snapshot()['daemon_sha256'] == state['daemon_sha256'])
        _, container_name, volume_name = names(state['owner'])
        volume, container = self.docker.volume(volume_name), self.docker.container(container_name)
        require(volume is None or volume == dict(owner=state['owner']))
        if container:
            require(volume and container['image'] in (state['image'], 'docker.io/'+state['image'])
                    and re.fullmatch('[0-9a-f]{64}', container['id'])
                    and container['mounts'] == [dict(type='volume', name=volume_name, destination='/var/lib/buildkit')])
        return container, volume

    def cleanup(self, state):
        container, volume = self.validate_backend(state)
        smoke=self.docker.smoke_resources(state['owner'])
        smoke_ids=set()
        for row in smoke['containers']:
            require(row['owner']==state['owner'] and row['scope']=='smoke' and row['privileged'] is False
                    and set(row['mount_types'])<={'tmpfs'} and re.fullmatch('[0-9a-f]{64}',row['id']))
            smoke_ids.add(row['id'])
        for row in smoke['networks']:
            require(row['owner']==state['owner'] and row['scope']=='smoke'
                    and re.fullmatch('release-smoke-[0-9a-f]{12}',row['name'])
                    and re.fullmatch('[0-9a-f]{64}',row['id']) and set(row['users'])<=smoke_ids)
        images = self.docker.matching_images(state['owner'])
        allowed_tags = {'voice-platform-'+service+':'+state['revision'] for service in ('api', 'web')}
        allowed_repos = {'voice-platform-api', 'voice-platform-web'}
        for image in images:
            require(image['owner'] == state['owner'] and image['revision'] == state['revision']
                    and image['archive'] == state['archive'] and re.fullmatch('sha256:[0-9a-f]{64}', image['id'])
                    and set(image['tags']) <= allowed_tags
                    and all(ref.split('@', 1)[0] in allowed_repos and re.fullmatch(r'[^@]+@sha256:[0-9a-f]{64}', ref)
                            for ref in image['digests']) and set(self.docker.image_users(image['id']))<=smoke_ids)
        # All ownership/ref-use checks finish before the first destructive call.
        for row in smoke['containers']:
            self.docker.remove_container(row['id'])
        for row in smoke['networks']:
            self.docker.remove_network(row['id'])
        if container:
            self.docker.remove_container(container['id'])
        if volume:
            self.docker.remove_volume(names(state['owner'])[2])
        for image in images:
            self.docker.remove_image(image['id'])
        require(self.docker.container(names(state['owner'])[1]) is None
                and self.docker.volume(names(state['owner'])[2]) is None
                and not self.docker.matching_images(state['owner']))
        remaining=self.docker.smoke_resources(state['owner'])
        require(not remaining['containers'] and not remaining['networks'])
        for key,rows in (('removed_smoke_container_count',smoke['containers']),('removed_smoke_network_count',smoke['networks'])):
            self.report[key]=self.report.get(key,0)+len(rows)
        return len(images)

    def finish(self, *, failed):
        if not self.active:
            return
        started = time.monotonic()
        try:
            if self.state:
                self.report['removed_image_count'] = self.cleanup(self.state)
                self.lease.clear()
            require(self.lease.read() is None)
            self.report.update(owned_resources_removed=True, filesystem_after=self.docker.snapshot(),
                               status='FAIL' if failed else 'PASS')
        except BaseException:
            self.report.update(status='FAIL', owned_resources_removed=False)
            raise ValueError('Owned builder cleanup is incomplete; journal retained') from None
        finally:
            self.report['cleanup_seconds'] = round(time.monotonic()-started,6)
            if self.old_signal is not None:
                signal.signal(signal.SIGTERM, self.old_signal)
            self.lease.__exit__()
            self.active = False

    def __exit__(self, kind, *_):
        self.finish(failed=kind is not None)
