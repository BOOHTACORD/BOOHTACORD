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

    def test_explicit_server_path_has_one_source_of_truth(self):
        data = {'components': [{'id': 'cmp.backend.voice',
                                'paths': ['backend/internal/voice/service.go']}], 'features': []}
        resolved = resolve_catalog(data, {})
        self.assertEqual(resolved['components'][0]['paths'], ['backend/internal/voice/service.go'])
        data['components'][0]['source'] = {'parity_id': 'voice.test', 'platform': 'web'}
        with self.assertRaisesRegex(ValueError, 'exactly one'):
            resolve_catalog(data, {})

    def test_missing_component_path_source_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'exactly one'):
            resolve_catalog({'components': [{'id': 'cmp.missing'}], 'features': []}, {})
