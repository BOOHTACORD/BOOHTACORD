import unittest

from tools.product_map.catalog.enrich import enrich_projection


class EnrichTests(unittest.TestCase):
    def test_attaches_components_without_changing_other_features(self):
        projection = [{'id': 'voice.a'}, {'id': 'other.b'}]
        catalog = {'features': [{'id': 'voice.a', 'title': 'A',
                                 'components': ['cmp.shared.a']}],
                   'components': [{'id': 'cmp.shared.a', 'paths': ['a.dart']}]}
        actual = enrich_projection(projection, catalog)
        self.assertEqual(actual[0]['components'][0]['paths'], ['a.dart'])
        self.assertEqual(actual[1], {'id': 'other.b'})
        self.assertNotIn('components', projection[0])

    def test_graph_includes_transitive_dependencies_without_duplicate_nodes(self):
        projection = [{'id': 'voice.a'}]
        catalog = {'features': [{'id': 'voice.a', 'title': 'A',
                                 'components': ['cmp.route', 'cmp.shared']}],
                   'components': [
                       {'id': 'cmp.route', 'paths': ['route.go'], 'depends_on': ['cmp.shared']},
                       {'id': 'cmp.shared', 'paths': ['shared.go'], 'depends_on': ['cmp.db']},
                       {'id': 'cmp.db', 'paths': ['db.go']},
                   ]}
        feature = enrich_projection(projection, catalog)[0]
        self.assertEqual([c['id'] for c in feature['components']],
                         ['cmp.db', 'cmp.route', 'cmp.shared'])
        self.assertEqual(feature['component_edges'], [
            {'from': 'cmp.route', 'to': 'cmp.shared', 'type': 'depends_on'},
            {'from': 'cmp.shared', 'to': 'cmp.db', 'type': 'depends_on'},
        ])
