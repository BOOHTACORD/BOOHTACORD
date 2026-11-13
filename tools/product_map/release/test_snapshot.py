import hashlib
import json
import unittest

from tools.product_map.release.snapshot import create_snapshot


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.sha = 'a' * 40
        self.raw = json.dumps({'schema_version': 1, 'source_revision': self.sha,
                               'source_dirty': False, 'platform': 'windows',
                               'version': '1.0.52+88', 'release_id': 'test-r1',
                               'architectures': ['x64']}).encode()
        self.digest = hashlib.sha256(self.raw).hexdigest()
        self.catalog = {'features': [{'id': 'voice.test', 'target_revision': None,
                                    'components': ['cmp.voice'],
                                    'platforms': {'windows': {'state': 'UNKNOWN',
                                                              'revision': None,
                                                              'applicability': 'UNKNOWN'}}}]}

    def test_snapshot_keeps_release_and_runtime_unproven(self):
        result = create_snapshot(self.catalog, self.raw, self.sha, 'windows', self.digest)
        self.assertEqual(result['manifest_sha256'], self.digest)
        self.assertEqual(result['features']['voice.test']['revision'], None)
        self.assertIsNone(result['features']['voice.test']['target_revision'])
        self.assertEqual(result['published'], 'UNKNOWN')
        self.assertEqual(result['runtime'], 'NOT_VERIFIED')
        self.assertEqual(result['build_provenance'], 'UNVERIFIED')
        self.assertEqual(result, create_snapshot(self.catalog, self.raw, self.sha,
                                                  'windows', self.digest))

    def test_source_platform_and_manifest_digest_must_match(self):
        for sha, platform, digest in [('b' * 40, 'windows', self.digest),
                                      (self.sha, 'android', self.digest),
                                      (self.sha, 'windows', '0' * 64)]:
            with self.subTest(sha=sha, platform=platform, digest=digest):
                with self.assertRaises(ValueError):
                    create_snapshot(self.catalog, self.raw, sha, platform, digest)

    def test_dirty_manifest_and_invalid_revision_are_rejected(self):
        item = json.loads(self.raw)
        item['source_dirty'] = True
        raw = json.dumps(item).encode()
        with self.assertRaises(ValueError):
            create_snapshot(self.catalog, raw, self.sha, 'windows', hashlib.sha256(raw).hexdigest())
        self.catalog['features'][0]['platforms']['windows']['revision'] = 0
        with self.assertRaises(ValueError):
            create_snapshot(self.catalog, self.raw, self.sha, 'windows', self.digest)
