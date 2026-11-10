import unittest

from tools.product_map.catalog.resolve import resolve_catalog


class ResolveTests(unittest.TestCase):
    def test_resolves_original_path_and_keeps_catalog_unchanged(self):
        registry = {'voice': {'parity': [{'id': 'voice.test', 'platforms': {
            'web': {'entrypoint': 'src/web.ts'},
            'android': {'entrypoint': 'src/shared.dart'},
        }}]}}
        curated = {'components': [{'id': 'cmp.shared.voice', 'source': {
            'parity_id': 'voice.test', 'platform': 'android'}}], 'features': []}
        actual = resolve_catalog(curated, registry)
        self.assertEqual(actual['components'][0]['paths'], ['src/shared.dart'])
        self.assertNotIn('paths', curated['components'][0])

    def test_rejects_unknown_reference_or_platform(self):
        data = {'components': [{'id': 'cmp.shared.voice', 'source': {
            'parity_id': 'missing', 'platform': 'windows'}}], 'features': []}
        with self.assertRaisesRegex(ValueError, 'parity source'):
            resolve_catalog(data, {})
