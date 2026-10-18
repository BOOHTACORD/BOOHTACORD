import tempfile
import unittest
from pathlib import Path
from .builder_identity import cache_identity


class BuilderIdentityTests(unittest.TestCase):
    def test_cache_is_bound_to_sources_and_active_builder_dependencies(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            paths = ['tools/build/server/run.py', 'tools/audio/asset_build.py', 'tools/release/bundle/verify.py']
            for name in paths:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('public source\n')
            proof = {'current': {'head': 'a' * 40}, 'previous': {'head': 'b' * 40}}
            original = cache_identity(proof, root)
            for name in paths:
                (root / name).write_text('changed source\n')
                self.assertNotEqual(cache_identity(proof, root), original)
                (root / name).write_text('public source\n')
            proof['previous']['head'] = 'c' * 40
            self.assertNotEqual(cache_identity(proof, root), original)

    def test_unrelated_evidence_neither_invalidates_cache_nor_leaks_contents(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            proof = {'current': {'head': 'a' * 40}, 'previous': {'head': 'b' * 40}}
            original = cache_identity(proof, root)
            (root / 'private.txt').write_text('private-secret')
            self.assertEqual(cache_identity(proof, root), original)
            self.assertNotIn('private-secret', str(original))
