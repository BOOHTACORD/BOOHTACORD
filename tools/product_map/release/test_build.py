import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.product_map.release.build import build_verified_snapshot


class BuildTests(unittest.TestCase):
    def test_existing_gate_precedes_verified_provenance(self):
        sha = 'a' * 40
        manifest = {'schema_version': 1, 'source_revision': sha, 'source_dirty': False,
                    'platform': 'windows', 'version': '1.0.0+1', 'release_id': 'test',
                    'architectures': ['x64']}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            registry = root / 'tools/qa/local_features/features.json'
            registry.parent.mkdir(parents=True)
            registry.write_text('{}')
            path = root / 'artifact-manifest.json'
            raw = json.dumps(manifest).encode()
            path.write_bytes(raw)
            catalog = {'features': []}
            with patch('tools.product_map.release.build.preflight',
                       return_value={'source_revision': sha, 'execution': {'run_id': '1', 'run_attempt': '1'}}), \
                 patch('tools.product_map.release.build.require_exact_source') as check, \
                 patch('tools.product_map.release.build.load_curated_catalog', return_value=catalog), \
                 patch('tools.product_map.release.build.validate_assets',
                       return_value={'manifest_sha256': hashlib.sha256(raw).hexdigest()}) as gate:
                result = build_verified_snapshot(root, 'windows', path)
                self.assertEqual(check.call_count, 2)
                gate.assert_called_once()
                self.assertEqual(result['build_provenance'], 'VERIFIED_ASSET_CONTRACT')
                self.assertEqual(result['published'], 'UNKNOWN')
                self.assertEqual(result['runtime'], 'NOT_VERIFIED')
                gate.side_effect = ValueError('untrusted artifact')
                with self.assertRaisesRegex(ValueError, 'untrusted artifact'):
                    build_verified_snapshot(root, 'windows', path)
