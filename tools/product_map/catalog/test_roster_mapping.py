import json
import unittest
from pathlib import Path

from tools.product_map.catalog.curated import load_curated_catalog


class VoiceRosterMappingTests(unittest.TestCase):
    def test_roster_recovery_maps_registry_entrypoints_without_claiming_support(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json')
                              .read_text(encoding='utf-8'))
        catalog = load_curated_catalog(root, registry)
        feature = next(row for row in catalog['features']
                       if row['id'] == 'voice.roster_long_recovery')
        self.assertEqual(feature['parity_ids'], ['voice.roster_long_recovery'])
        paths = {path for item in catalog['components']
                 if item['id'] in feature['components'] for path in item['paths']}
        parity = next(row for row in registry['voice']['parity']
                      if row['id'] == 'voice.roster_long_recovery')
        self.assertEqual(paths, {value['entrypoint']
                                 for value in parity['platforms'].values()})
        self.assertEqual(set(feature['platforms']),
                         {'web', 'windows', 'macos', 'android', 'ios'})
        for platform in feature['platforms'].values():
            self.assertEqual(platform['applicability'], 'UNKNOWN')
            self.assertEqual(platform['state'], 'UNKNOWN')
            self.assertIsNone(platform['revision'])
