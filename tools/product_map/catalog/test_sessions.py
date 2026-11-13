import json
import unittest
from pathlib import Path

from tools.product_map.catalog.curated import load_curated_catalog
from tools.product_map.catalog.enrich import enrich_projection
from tools.product_map.impact.analyze import analyze
from tools.product_map.projection.importer import import_parity


class OwnSessionsCatalogTests(unittest.TestCase):
    def test_real_session_sources_and_independent_platform_states(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json').read_text(encoding='utf-8'))
        catalog = load_curated_catalog(root, registry)
        rows = {row['id']: row for row in enrich_projection(import_parity(registry), catalog)}
        row = rows['auth.own_sessions']
        ids = {component['id'] for component in row['components']}
        self.assertTrue({'cmp.web.own_sessions_panel', 'cmp.flutter.own_sessions_panel',
                         'cmp.backend.own_session_routes', 'cmp.backend.revoke_own_sessions'} <= ids)
        self.assertIn({'from': 'cmp.web.own_sessions_state',
                       'to': 'cmp.web.own_sessions_client', 'type': 'depends_on'},
                      row['component_edges'])
        self.assertEqual(len(row['platforms']), 5)
        self.assertTrue(all(value['source_status'] == 'UNKNOWN' and value['released'] == 'UNKNOWN'
                            for value in row['platforms'].values()))
        path = 'backend/internal/identity/revoke_own_sessions/postgres/repository.go'
        impact = analyze([path], catalog)
        self.assertIn('auth.own_sessions', impact['direct_features'])
        self.assertIn('cmp.backend.revoke_own_sessions', impact['components'])
