"""Owned builder storage survives failures without deleting another workload."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from .builder_storage import BuilderStorage

REVISION = 'a' * 40
ARCHIVE = 'b' * 64
IMAGE = 'moby/buildkit@sha256:' + 'c' * 64


class DockerFixture:
    def __init__(self):
        self.volumes = {}
        self.containers = {}
        self.images = {}
        self.smoke_containers = {}
        self.smoke_networks = {}
        self.calls = []
        self.fail_bootstrap = False
        self.fail_remove = False
        self.free = 64 * 1024**3

    def snapshot(self):
        return dict(daemon_sha256='d'*64, filesystem_available_bytes=self.free,
                    filesystem_used_bytes=1024**3, image_count=len(self.images))

    def volume(self, name):
        return copy.deepcopy(self.volumes.get(name))

    def container(self, name):
        return copy.deepcopy(self.containers.get(name))

    def create_volume(self, name, owner):
        self.calls.append(('create-volume', name))
        if name not in self.volumes:
            self.volumes[name] = dict(owner=owner)

    def create_builder(self, name, image, config):
        self.calls.append(('create-builder', name, image, config.read_text()))
        if self.fail_bootstrap:
            raise ValueError('private-bootstrap-canary')
        self.containers['buildx_buildkit_'+name+'0'] = dict(
            id='e'*64, image=image,
            mounts=[dict(type='volume', name='buildx_buildkit_'+name+'0_state', destination='/var/lib/buildkit')])

    def matching_images(self, owner):
        return [copy.deepcopy(row) for row in self.images.values()
                if row['owner'] == owner]

    def tag_image(self, tag):
        return next((copy.deepcopy(row) for row in self.images.values() if tag in row['tags']), None)

    def add_image(self, identity, *, revision=REVISION, archive=ARCHIVE, tags=None, used=False, owner=None):
        self.images[identity] = dict(id=identity, revision=revision, archive=archive,
                                    tags=tags or [], digests=[], used=used, owner=owner)

    def image_users(self, identity):
        return (['f'*64] if self.images[identity]['used'] else []) + [
            row['id'] for row in self.smoke_containers.values() if row.get('image')==identity]

    def in_use(self, identity):
        return bool(self.image_users(identity))

    def smoke_resources(self, owner):
        return {kind:[copy.deepcopy(row) for row in rows.values() if row['owner']==owner]
                for kind,rows in (('containers',self.smoke_containers),('networks',self.smoke_networks))}

    def remove_container(self, identity):
        self.calls.append(('remove-container', identity))
        if self.fail_remove:
            raise ValueError('private-remove-canary')
        for name, row in list(self.containers.items()):
            if row['id'] == identity:
                del self.containers[name]
        self.smoke_containers.pop(identity,None)

    def remove_network(self, identity):
        self.calls.append(('remove-network',identity))
        del self.smoke_networks[identity]

    def remove_volume(self, name):
        self.calls.append(('remove-volume', name))
        del self.volumes[name]

    def remove_image(self, identity):
        self.calls.append(('remove-image', identity))
        del self.images[identity]


class BuilderStorageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root/'tools/build/server').mkdir(parents=True)
        self.pin = self.root/'tools/build/server/buildkit-image.json'
        self.pin.write_text(json.dumps(dict(schema_version=1,version='0.33.1',image=IMAGE)))
        self.environment = {'DOCKER_CONFIG': str(self.root/'docker')}
        (self.root/'docker').mkdir(mode=0o700)
        self.docker = DockerFixture()

    def scope(self):
        return BuilderStorage(self.root, self.environment, REVISION, ARCHIVE,
                              lease_root=self.root/'lease', docker=self.docker)

    def test_success_removes_only_new_owned_images_and_builder_state(self):
        old = 'sha256:'+'1'*64
        new = 'sha256:'+'2'*64
        foreign = 'sha256:'+'3'*64
        self.docker.add_image(old, revision='9'*40, tags=['voice-platform-api:'+'9'*40])
        self.docker.add_image(foreign, revision='f'*40, tags=['another-project:stable'])
        with self.scope() as storage:
            self.assertNotIn('BUILDX_BUILDER', self.environment)
            self.assertTrue(storage.environment['BUILDX_BUILDER'].startswith('boohtacord-server-'))
            self.docker.add_image(new, tags=['voice-platform-web:'+REVISION], owner=storage.environment['BOOHTACORD_BUILD_OWNER'])
        self.assertEqual({old, foreign}, set(self.docker.images))
        self.assertFalse(self.docker.containers or self.docker.volumes)
        self.assertTrue(storage.report['owned_resources_removed'])
        self.assertEqual(1, storage.report['removed_image_count'])
        self.assertEqual(IMAGE, next(c for c in self.docker.calls if c[0]=='create-builder')[2])
        self.assertFalse((self.root/'lease/active.json').exists())

    def test_build_failure_and_interrupt_still_cleanup(self):
        for failure in (RuntimeError('private-build-canary'), KeyboardInterrupt()):
            with self.subTest(failure=type(failure).__name__):
                with self.assertRaises(type(failure)):
                    with self.scope() as storage:
                        raise failure
                self.assertFalse(self.docker.containers or self.docker.volumes)
                self.assertTrue(storage.report['owned_resources_removed'])
                self.assertNotIn('canary', json.dumps(storage.report))

    def test_bootstrap_failure_removes_precreated_owned_volume(self):
        self.docker.fail_bootstrap = True
        with self.assertRaises(ValueError):
            with self.scope():
                self.fail('Bootstrap failed')
        self.assertFalse(self.docker.containers or self.docker.volumes)

    def test_foreign_matching_tag_blocks_before_any_resource_mutation(self):
        self.docker.add_image('sha256:'+'4'*64, archive='f'*64, tags=['voice-platform-api:'+REVISION])
        with self.assertRaises(ValueError):
            with self.scope():
                self.fail('Foreign tag was accepted')
        self.assertFalse(self.docker.calls)

    def test_foreign_alias_or_active_container_prevents_image_deletion(self):
        for options in (dict(tags=['other-project:stable']), dict(tags=['voice-platform-api:'+REVISION], used=True)):
            with self.subTest(options=options):
                self.docker = DockerFixture()
                with self.assertRaises(ValueError):
                    with self.scope() as storage:
                        self.docker.add_image('sha256:'+'5'*64, owner=storage.environment['BOOHTACORD_BUILD_OWNER'], **options)
                self.assertFalse(storage.report['owned_resources_removed'])
                self.assertIn('sha256:'+'5'*64, self.docker.images)
                # Remove the deliberately blocked private fixture lease for the next subcase.
                (self.root/'lease/active.json').unlink()

    def test_changed_volume_owner_is_never_deleted(self):
        with self.assertRaises(ValueError):
            with self.scope() as storage:
                next(iter(self.docker.volumes.values()))['owner'] = 'foreign-owner'
        self.assertFalse(storage.report['owned_resources_removed'])
        self.assertTrue(self.docker.volumes)
        self.assertFalse(any(c[0].startswith('remove-') for c in self.docker.calls))

    def test_existing_exact_source_tag_is_preserved_without_overwrite(self):
        self.docker.add_image('sha256:'+'6'*64, tags=['voice-platform-web:'+REVISION])
        with self.assertRaises(ValueError):
            with self.scope():
                self.fail('An existing target was overwritten')
        self.assertIn('sha256:'+'6'*64, self.docker.images)
        self.assertFalse(self.docker.calls)

    def test_failed_cleanup_is_persisted_and_recovered_under_next_exclusive_lease(self):
        self.docker.fail_remove = True
        with self.assertRaises(ValueError):
            with self.scope() as failed:
                pass
        self.assertFalse(failed.report['owned_resources_removed'])
        self.assertTrue((self.root/'lease/active.json').is_file())
        self.docker.fail_remove = False
        with self.scope() as recovered:
            self.assertEqual(1, len(self.docker.volumes))
        self.assertTrue(recovered.report['recovered_previous_lease'])
        self.assertFalse(self.docker.containers or self.docker.volumes)

    def test_second_live_controller_cannot_cleanup_first_controller(self):
        with self.scope():
            before = copy.deepcopy(self.docker.calls)
            with self.assertRaises(ValueError):
                with self.scope():
                    self.fail('Exclusive controller lease was bypassed')
            self.assertEqual(before, self.docker.calls)

    def test_space_is_remeasured_after_reclaiming_an_abandoned_backend(self):
        self.docker.fail_remove=True
        with self.assertRaises(ValueError):
            with self.scope():pass
        self.docker.fail_remove=False
        self.docker.free=13*1024**3
        original=self.docker.remove_volume
        def reclaimed(name):
            original(name)
            self.docker.free+=2*1024**3
        self.docker.remove_volume=reclaimed
        with self.scope() as recovered:
            self.assertTrue(recovered.report['recovered_previous_lease'])
        self.assertTrue(recovered.report['owned_resources_removed'])

    def test_rejected_orphan_cannot_claim_successful_cleanup(self):
        self.docker.fail_remove = True
        with self.assertRaises(ValueError):
            with self.scope():pass
        self.docker.fail_remove = False
        next(iter(self.docker.volumes.values()))['owner'] = 'another-controller'
        rejected = self.scope()
        before = list(self.docker.calls)
        with self.assertRaises(ValueError):
            with rejected:self.fail('Unverified orphan accepted')
        self.assertFalse(rejected.report['owned_resources_removed'])
        self.assertTrue((self.root/'lease/active.json').is_file())
        self.assertEqual(before, self.docker.calls)

    def smoke_fixture(self, storage):
        owner=storage.environment['BOOHTACORD_BUILD_OWNER'];identity='sha256:'+'7'*64
        self.docker.add_image(identity,tags=['voice-platform-api:'+REVISION],owner=owner)
        self.docker.smoke_containers['8'*64]=dict(id='8'*64,owner=owner,scope='smoke',
            privileged=False,mount_types=['tmpfs'],image=identity)
        self.docker.smoke_networks['9'*64]=dict(id='9'*64,name='release-smoke-'+'a'*12,
            owner=owner,scope='smoke',users=['8'*64])

    def test_abandoned_smoke_containers_and_network_do_not_block_owned_image_cleanup(self):
        with self.assertRaisesRegex(RuntimeError,'injected'):
            with self.scope() as storage:
                self.smoke_fixture(storage)
                raise RuntimeError('injected')
        self.assertTrue(storage.report['owned_resources_removed'])
        self.assertFalse(self.docker.smoke_containers or self.docker.smoke_networks or self.docker.images)

    def test_foreign_network_user_or_smoke_host_bind_blocks_all_deletion(self):
        for mutation in ('network-user','bind','privileged'):
            with self.subTest(mutation=mutation):
                self.docker=DockerFixture()
                with self.assertRaises(ValueError):
                    with self.scope() as storage:
                        self.smoke_fixture(storage)
                        if mutation=='network-user':self.docker.smoke_networks['9'*64]['users'].append('b'*64)
                        if mutation=='bind':self.docker.smoke_containers['8'*64]['mount_types']=['bind']
                        if mutation=='privileged':self.docker.smoke_containers['8'*64]['privileged']=True
                self.assertFalse(storage.report['owned_resources_removed'])
                self.assertFalse(any(c[0].startswith('remove-') for c in self.docker.calls))
                (self.root/'lease/active.json').unlink()

    def test_unpinned_backend_and_low_space_fail_before_creation(self):
        for image in ('moby/buildkit:latest', 'other-registry.invalid/buildkit@sha256:'+'c'*64):
            self.pin.write_text(json.dumps(dict(schema_version=1,version='0.33.1',image=image)))
            with self.assertRaises(ValueError):
                with self.scope():
                    self.fail('Mutable or foreign backend accepted')
            self.assertFalse(self.docker.calls)
        self.pin.write_text(json.dumps(dict(schema_version=1,version='0.33.1',image=IMAGE)))
        self.docker.free = 1024
        with self.assertRaises(ValueError):
            with self.scope():
                self.fail('Low storage was accepted')
        self.assertFalse(self.docker.calls)

    def test_foreign_lease_root_symlink_and_unknown_files_are_preserved(self):
        lease = self.root/'lease'
        lease.mkdir(mode=0o700)
        foreign = lease/'foreign-data'
        foreign.write_text('must remain')
        with self.assertRaises(ValueError):
            with self.scope():
                self.fail('Unknown lease root accepted')
        self.assertEqual('must remain', foreign.read_text())
        self.assertFalse(self.docker.calls)

