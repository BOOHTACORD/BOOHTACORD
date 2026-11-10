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
