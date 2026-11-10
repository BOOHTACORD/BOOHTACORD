import json
import tempfile
from copy import deepcopy
import unittest
from pathlib import Path

from tools.product_map.catalog.curated import load_curated_catalog
from tools.product_map.impact.analyze import analyze


class CuratedCatalogTests(unittest.TestCase):
    def test_every_existing_parity_scenario_has_a_curated_mapping(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json')
                              .read_text(encoding='utf-8'))
        catalog = load_curated_catalog(root, registry)
        all_ids = {row['id'] for group in registry.values() for row in group['parity']}
        covered = {ref for feature in catalog['features'] for ref in feature['parity_ids']}
        self.assertEqual(covered, all_ids)

    def test_existing_voice_and_workspace_slices_share_components(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json')
                              .read_text(encoding='utf-8'))
        result = load_curated_catalog(root, registry)
        indexed = {row['id']: row for row in result['features']}
        self.assertTrue({'auth.session', 'chat.text-dm', 'screen.viewer.commands',
                         'screen.viewer.compact_participants', 'notifications.foreground',
                         'notifications.addressed_background_v1', 'voice.controls'} <= indexed.keys())
        for identifier in ('auth.session', 'chat.text-dm', 'screen.viewer.commands',
                           'notifications.foreground'):
            self.assertIn('cmp.web.workspace', indexed[identifier]['components'])
        self.assertEqual(sum(c['id'] == 'cmp.web.workspace' for c in result['components']), 1)
        background = indexed['notifications.addressed_background_v1']['components']
        self.assertIn('cmp.android.push_driver', background)
        self.assertIn('cmp.ios.push_adapter', background)
        changed = deepcopy(registry)
        for group in changed.values():
            for row in group['parity']:
                if row['id'] == 'chat.text-dm':
                    row['platforms']['web']['entrypoint'] = 'clients/web/src/voice/VoiceDock.vue'
        with self.assertRaisesRegex(ValueError, 'entrypoint'):
            load_curated_catalog(root, changed)

    def test_catalog_symlink_cannot_escape_repository(self):
        with tempfile.TemporaryDirectory() as tmp, tempfile.TemporaryDirectory() as outside:
            root = Path(tmp)
            (root / 'product-map').mkdir()
            try:
                (root / 'product-map/features').symlink_to(outside, target_is_directory=True)
            except OSError as error:
                self.skipTest(f'symlink creation unavailable: {error}')
            with self.assertRaisesRegex(ValueError, 'catalog'):
                load_curated_catalog(root, {})

    def test_new_parity_scenario_requires_an_explicit_mapping(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json')
                              .read_text(encoding='utf-8'))
        extra = deepcopy(registry['voice']['parity'][0])
        extra['id'] = 'voice.new_unmapped'
        registry['voice']['parity'].append(extra)
        with self.assertRaisesRegex(ValueError, 'not fully mapped'):
            load_curated_catalog(root, registry)

    def test_voice_melody_includes_real_server_routes(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json')
                              .read_text(encoding='utf-8'))
        catalog = load_curated_catalog(root, registry)
        features = {item['id']: item for item in catalog['features']}
        components = {item['id']: item for item in catalog['components']}
        ids = features['voice.event-sounds-private-melody']['components']
        self.assertIn('cmp.backend.voice_join_sound_routes', ids)
        self.assertEqual(components['cmp.backend.voice_join_sound_routes']['paths'],
                         ['backend/internal/app/voice_sound_routes/join.go'])
        self.assertEqual(components['cmp.backend.voice_join_sound_routes']['depends_on'],
                         ['cmp.backend.voice_join_sound_service'])
        self.assertIn('cmp.backend.voice_sound_preferences_routes',
                      features['voice.room_event_sounds']['components'])
        impact = analyze(['backend/internal/voice/join_sound/service.go'], catalog)
        self.assertIn('voice.event-sounds-private-melody', impact['direct_features'])
        self.assertIn('cmp.backend.voice_join_sound_routes', impact['components'])
