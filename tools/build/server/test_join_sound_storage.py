"""The signed worker follows the same guarded builder ownership as API/Web."""
import unittest
from . import test_builder_storage as fixtures

REVISION = fixtures.REVISION


class JoinSoundStorageTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.BuilderStorageTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.docker = self.fixture.docker

    def test_all_three_owned_images_are_removed_but_foreign_image_survives(self):
        foreign = 'sha256:'+'9'*64
        self.docker.add_image(foreign, revision='f'*40, tags=['foreign:stable'])
        with self.fixture.scope() as storage:
            for index, service in enumerate(('api', 'web', 'join-sound-processor')):
                identity = 'sha256:'+str(index)*64
                self.docker.add_image(identity, owner=storage.state['owner'],
                    tags=['voice-platform-'+service+':'+REVISION])
                self.docker.images[identity]['digests'] = ['voice-platform-'+service+'@'+identity]
        self.assertEqual({foreign}, set(self.docker.images))
        self.assertEqual(3, storage.report['removed_image_count'])
        self.assertTrue(storage.report['owned_resources_removed'])

    def test_existing_worker_tag_is_never_overwritten(self):
        self.docker.add_image('sha256:'+'8'*64, tags=['voice-platform-join-sound-processor:'+REVISION])
        with self.assertRaises(ValueError):
            with self.fixture.scope(): self.fail('Existing worker tag was accepted')
        self.assertFalse(self.docker.calls)

    def test_worker_with_foreign_alias_is_never_deleted(self):
        identity = 'sha256:'+'7'*64
        with self.assertRaises(ValueError):
            with self.fixture.scope() as storage:
                self.docker.add_image(identity, owner=storage.state['owner'],
                    tags=['voice-platform-join-sound-processor:'+REVISION, 'foreign:stable'])
        self.assertIn(identity, self.docker.images)
        self.assertFalse(any(call[0].startswith('remove-') for call in self.docker.calls))
