import unittest

from tools.product_map.projection.compare import compare


class CompareTests(unittest.TestCase):
    def test_reports_source_release_and_runtime_separately(self):
        item = {'id': 'voice.example', 'platforms': {
            'web': {'implementation': 'UNKNOWN', 'released': 'UNKNOWN',
                    'runtime': 'NOT_RUN'},
            'windows': {'implementation': 'UNKNOWN', 'released': 'UNKNOWN',
                        'runtime': 'NOT_VERIFIED'},
        }}
        row = compare([item], 'web', 'windows')[0]
        self.assertEqual(row['web']['runtime'], 'NOT_RUN')
        self.assertEqual(row['windows']['runtime'], 'NOT_VERIFIED')
        self.assertEqual(row['windows']['released'], 'UNKNOWN')

    def test_unknown_platform_fails(self):
        with self.assertRaises(ValueError):
            compare([], 'server', 'web')
