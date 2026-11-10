import json
import unittest
from pathlib import Path

from tools.product_map.catalog.curated import load_curated_catalog
from tools.product_map.catalog.enrich import enrich_projection
from tools.product_map.impact.analyze import analyze
from tools.product_map.projection.importer import import_parity


class MelodyCatalogTests(unittest.TestCase):
    def test_melody_client_processor_and_storage_are_linked(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json').read_text(encoding='utf-8'))
        catalog = load_curated_catalog(root, registry)
        rows = {row['id']: row for row in enrich_projection(import_parity(registry), catalog)}
        row = rows['voice.event-sounds-private-melody']
        ids = {item['id'] for item in row['components']}
        self.assertTrue({'cmp.web.voice_melody_client', 'cmp.flutter.voice_melody_controls',
                         'cmp.flutter.voice_melody_api', 'cmp.backend.voice_join_sound_processor'} <= ids)
        self.assertIn({'from': 'cmp.web.voice_melody', 'to': 'cmp.web.voice_melody_client',
                       'type': 'depends_on'}, row['component_edges'])
        for path in ('clients/web/src/voice/join_sound/client.ts',
                     'clients/flutter/lib/src/features/voice/join_sound/selection.dart',
                     'backend/internal/voice/join_sound/postgres/repository.go'):
            with self.subTest(path=path):
                impact = analyze([path], catalog)
                self.assertIn('voice.event-sounds-private-melody', impact['direct_features'])
                self.assertEqual(impact['unclassified_runtime_paths'], [])
