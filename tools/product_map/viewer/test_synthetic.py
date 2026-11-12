import unittest

from tools.product_map.viewer.synthetic import synthetic_features


class SyntheticFeaturesTests(unittest.TestCase):
    def test_fixture_uses_independent_features_with_unique_stable_ids(self):
        sample = {'id': 'example', 'description': 'original',
                  'platforms': {'web': {'source_status': 'UNKNOWN'}}}
        rows = synthetic_features(sample, 1001)
        self.assertEqual(len(rows), 1001)
        self.assertEqual(len({row['id'] for row in rows}), 1001)
        rows[0]['platforms']['web']['source_status'] = 'BEHIND'
        self.assertEqual(rows[1]['platforms']['web']['source_status'], 'UNKNOWN')
        self.assertEqual(sample['id'], 'example')

    def test_rejects_unbounded_or_invalid_counts(self):
        for count in (0, 10001, -1, True, 1.5):
            with self.subTest(count=count), self.assertRaises(ValueError):
                synthetic_features({}, count)
