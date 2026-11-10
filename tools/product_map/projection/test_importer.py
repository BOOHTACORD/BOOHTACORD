import unittest

from tools.product_map.projection.importer import import_parity


class ImportParityTests(unittest.TestCase):
    def row(self):
        return {
            'id': 'voice.test', 'expected': 'Voice works', 'issue': 688,
            'platforms': {
                'web': {'entrypoint': 'web/a', 'tests': ['web/test'],
                        'runtime': 'PASS', 'evidence': 'missing'},
                'android': {'entrypoint': 'native/a', 'tests': ['native/test'],
                            'runtime': 'NOT_RUN'},
                'ios': {'entrypoint': 'native/a', 'tests': ['native/test'],
                        'runtime': 'NOT_VERIFIED'},
            },
        }

    def test_preserves_ids_and_never_infers_releases_or_desktop_runtime(self):
        data = import_parity({'voice': {'parity': [self.row()]}})
        self.assertEqual(data[0]['id'], 'voice.test')
        self.assertEqual(set(data[0]['platforms']),
                         {'web', 'windows', 'macos', 'android', 'ios'})
        self.assertEqual(data[0]['platforms']['windows']['runtime'], 'NOT_VERIFIED')
        self.assertEqual(data[0]['platforms']['web']['runtime'], 'NOT_VERIFIED')
        self.assertEqual(data[0]['platforms']['web']['declared_runtime'], 'PASS')
        self.assertEqual(data[0]['platforms']['web']['source_status'], 'UNKNOWN')
        self.assertTrue(all(p['released'] == 'UNKNOWN'
                            for p in data[0]['platforms'].values()))

    def test_rejects_duplicate_or_missing_platform(self):
        row = self.row()
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            import_parity({'a': {'parity': [row, row]}})
        del row['platforms']['web']
        with self.assertRaisesRegex(ValueError, 'platform'):
            import_parity({'a': {'parity': [row]}})
