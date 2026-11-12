import json
import unittest
from pathlib import Path

from tools.product_map.catalog.pilot import load_voice_slice


class VoiceSliceTests(unittest.TestCase):
    def test_resolves_real_components_and_reports_partial_coverage(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json')
                              .read_text(encoding='utf-8'))
        result = load_voice_slice(root, registry)
        self.assertEqual({f['id'] for f in result['features']}, {
            'voice.controls', 'voice.long_recovery', 'voice.roster_long_recovery',
            'voice.room_event_sounds',
            'voice.event-sounds-private-melody'})
        self.assertTrue({'cmp.backend.voice_join_sound_routes',
                         'cmp.backend.voice_join_sound_service',
                         'cmp.web.voice_controls', 'cmp.flutter.voice_controller'} <=
                        {component['id'] for component in result['components']})
        for feature in result['features']:
            self.assertIsNone(feature['target_revision'])
            self.assertTrue(all(p['state'] == 'UNKNOWN'
                                for p in feature['platforms'].values()))
