import copy
import unittest
import tempfile
from pathlib import Path
from . import test_cached_images as cached
from tools.release.bundle.manifest import validate
from tools.release.bundle.test_manifest import fixture

class JoinSoundDeliveryTests(unittest.TestCase):
    def test_present_worker_is_built_with_source_binding_and_attested_exports(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); (root/'backend').mkdir()
            (root/'backend/Dockerfile.join-sound-worker').touch()
            cache, verified, commands = cached.CachedImageTests().build(root)
        self.assertEqual(6, verified.call_count)
        self.assertEqual(3, cache.publish.call_count)
        builds = [call.args[0] for call in commands.call_args_list if call.args[0][:3] == ['docker','buildx','build']]
        worker = [args for args in builds if any('Dockerfile.join-sound-worker' in arg for arg in args)]
        self.assertEqual(2,len(worker))
        self.assertIn('--sbom=true',worker[0]); self.assertIn('--provenance=mode=max,version=v0.2',worker[0])
    def test_worker_requires_its_signed_payload_and_attestations(self):
        manifest = fixture()
        worker = copy.deepcopy(manifest['components']['api'])
        worker['archive'] = 'join-sound-processor.oci.tar'
        manifest['components']['join-sound-processor'] = worker
        with self.assertRaises(ValueError): validate(manifest)
        manifest['files'][worker['archive']] = {'sha256':'a'*64, 'bytes':1}
        validate(manifest)
        worker['attestation_predicates'] = []
        with self.assertRaises(ValueError): validate(manifest)

if __name__ == '__main__': unittest.main()
