import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[3]


class ReleaseWorkflowTests(unittest.TestCase):
    def test_sidecar_is_created_after_asset_verification_before_publication(self):
        for platform in ('windows', 'macos', 'android'):
            with self.subTest(platform=platform):
                path = ROOT / '.github/workflows' / f'{platform}-release.yaml'
                doc = yaml.load(path.read_text(encoding='utf-8'), Loader=yaml.BaseLoader)
                steps = doc['jobs'][f'{platform}-release']['steps']
                commands = [s.get('run', '') for s in steps]
                gate = next(i for i, value in enumerate(commands)
                            if f'native_contract.run assets {platform}' in value)
                sidecar = next(i for i, value in enumerate(commands)
                               if f'product_map release-snapshot --platform {platform}' in value)
                publication = next(i for i, value in enumerate(commands)
                                   if 'native_contract/publish.mjs' in value)
                self.assertLess(gate, sidecar)
                self.assertLess(sidecar, publication)
                self.assertNotIn('if', steps[sidecar])
                self.assertTrue(any(s.get('with', {}).get('path') ==
                                    f'.out/native-release/{platform}/' for s in steps))
