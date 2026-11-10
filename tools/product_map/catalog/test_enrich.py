import unittest

from tools.product_map.catalog.enrich import enrich_projection
from tools.product_map.catalog.test_feature_projection import feature


class EnrichTests(unittest.TestCase):
    def test_attaches_components_without_changing_other_features(self):
        projection = [{'id': 'voice.a', 'platforms': {}}, {'id': 'other.b'}]
        item = dict(feature(), title='A', components=['cmp.shared.a'])
        catalog = {'features': [item],
                   'components': [{'id': 'cmp.shared.a', 'paths': ['a.dart']}]}
        actual = enrich_projection(projection, catalog)
        self.assertEqual(actual[0]['components'][0]['paths'], ['a.dart'])
        self.assertEqual(actual[1], {'id': 'other.b'})
        self.assertNotIn('components', projection[0])

    def test_graph_includes_transitive_dependencies_without_duplicate_nodes(self):
        projection = [{'id': 'voice.a', 'platforms': {}}]
        item = dict(feature(), title='A', components=['cmp.route', 'cmp.shared'])
        catalog = {'features': [item],
                   'components': [
                       {'id': 'cmp.route', 'paths': ['route.go'], 'depends_on': ['cmp.shared']},
                       {'id': 'cmp.shared', 'paths': ['shared.go'], 'depends_on': ['cmp.db']},
                       {'id': 'cmp.db', 'paths': ['db.go']},
                   ]}
        row = enrich_projection(projection, catalog)[0]
        self.assertEqual([c['id'] for c in row['components']],
                         ['cmp.db', 'cmp.route', 'cmp.shared'])
        self.assertEqual(row['component_edges'], [
            {'from': 'cmp.route', 'to': 'cmp.shared', 'type': 'depends_on'},
            {'from': 'cmp.shared', 'to': 'cmp.db', 'type': 'depends_on'},
        ])

    def test_catalog_only_feature_and_parity_crosswalk_are_visible(self):
        original = [{'id': 'voice.a', 'platforms': {}}]
        item = dict(feature(), id='voice.parent', components=['cmp.shared.a'])
        catalog = {'features': [item],
                   'components': [{'id': 'cmp.shared.a', 'paths': ['a.dart']}]}
        result = enrich_projection(original, catalog)
        rows = {row['id']: row for row in result}
        self.assertEqual(rows['voice.a']['catalog_feature_ids'], ['voice.parent'])
        self.assertEqual(rows['voice.parent']['parity_ids'], ['voice.a'])
        self.assertEqual(rows['voice.parent']['platforms']['windows']['source_status'], 'BEHIND')

    def test_same_id_without_explicit_parity_link_cannot_inherit_runtime(self):
        item = dict(feature(), parity_ids=[], components=['cmp.shared.a'])
        catalog = {'features': [item], 'components': [{'id': 'cmp.shared.a', 'paths': ['a.dart']}]}
        with self.assertRaisesRegex(ValueError, 'parity'):
            enrich_projection([{'id': 'voice.a', 'platforms': {}}], catalog)
