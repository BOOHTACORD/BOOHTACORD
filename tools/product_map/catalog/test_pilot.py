import json
import unittest
from pathlib import Path

from tools.product_map.catalog.curated import load_curated_catalog
from tools.product_map.catalog.pilot import load_voice_slice


class VoiceSliceTests(unittest.TestCase):
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

    def test_resolves_real_components_and_reports_partial_coverage(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json')
                              .read_text(encoding='utf-8'))
        result = load_voice_slice(root, registry)
        self.assertEqual({f['id'] for f in result['features']}, {
            'voice.controls', 'voice.long_recovery', 'voice.roster_long_recovery',
            'voice.room_event_sounds',
            'voice.event-sounds-private-melody', 'voice.idle-afk'})
        self.assertTrue({'cmp.backend.voice_join_sound_routes',
                         'cmp.backend.voice_join_sound_service',
                         'cmp.web.voice_controls', 'cmp.flutter.voice_controller',
                         'cmp.web.idle_afk', 'cmp.flutter.idle_afk',
                         'cmp.backend.afk_routing',
                         'cmp.backend.idle_afk_migration'} <=
                        {component['id'] for component in result['components']})
        for feature in result['features']:
            self.assertIsNone(feature['target_revision'])
            self.assertTrue(all(p['state'] == 'UNKNOWN'
                                for p in feature['platforms'].values()))
