import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.product_map.release.build import build_verified_snapshot
from tools.release.native_contract.test_assets import fixture

ROOT = Path(__file__).resolve().parents[3]


class AssetGateIntegrationTests(unittest.TestCase):
    def test_real_asset_validator_rejects_tamper_before_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory, context = fixture(Path(tmp), 'windows')
            with patch('tools.product_map.release.build.preflight', return_value=context), \
                 patch('tools.product_map.release.build.require_exact_source'):
                result = build_verified_snapshot(ROOT, 'windows', directory / 'artifact-manifest.json')
                self.assertEqual(result['build_provenance'], 'VERIFIED_ASSET_CONTRACT')
                self.assertEqual(result['published'], 'UNKNOWN')
                self.assertTrue({'auth.registration', 'voice.controls'} <= result['features'].keys())
                next(directory.glob('*Setup.exe')).write_bytes(b'tampered')
                with self.assertRaises(ValueError):
                    build_verified_snapshot(ROOT, 'windows', directory / 'artifact-manifest.json')
