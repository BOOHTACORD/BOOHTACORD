import unittest

from tools.product_map.impact.analyze import analyze


class ImpactTests(unittest.TestCase):
    def setUp(self):
        self.catalog = {
            'components': [
                {'id': 'cmp.shared', 'paths': ['clients/flutter/lib/shared.dart']},
                {'id': 'cmp.web', 'paths': ['clients/web/src/voice.ts']},
            ],
            'features': [
                {'id': 'voice.a', 'components': ['cmp.shared'], 'depends_on': []},
                {'id': 'voice.b', 'components': ['cmp.shared', 'cmp.web'], 'depends_on': []},
                {'id': 'voice.c', 'components': ['cmp.web'], 'depends_on': ['voice.a']},
            ],
        }

    def test_shared_component_and_transitive_dependents_are_reported(self):
        result = analyze(['clients/flutter/lib/shared.dart'], self.catalog)
        self.assertEqual(result['components'], ['cmp.shared'])
        self.assertEqual(result['direct_features'], ['voice.a', 'voice.b'])
        self.assertEqual(result['dependent_features'], ['voice.c'])
        self.assertEqual(result['unclassified_runtime_paths'], [])

    def test_unmapped_runtime_paths_are_not_silent_and_docs_are_separate(self):
        result = analyze(['backend/internal/new.go', 'docs/guide.md',
                          'clients/web/src/voice.ts'], self.catalog)
        self.assertEqual(result['direct_features'], ['voice.b', 'voice.c'])
        self.assertEqual(result['unclassified_runtime_paths'], ['backend/internal/new.go'])
        self.assertEqual(result['other_paths'], ['docs/guide.md'])
        self.assertEqual(result['coverage'], 'INCOMPLETE')

    def test_changed_dependency_impacts_consuming_component_and_feature(self):
        self.catalog['components'].append({'id': 'cmp.backend',
            'paths': ['backend/internal/voice/service.go']})
        self.catalog['components'][0]['depends_on'] = ['cmp.backend']
        result = analyze(['backend/internal/voice/service.go'], self.catalog)
        self.assertEqual(result['components'], ['cmp.backend', 'cmp.shared'])
        self.assertEqual(result['direct_features'], ['voice.a', 'voice.b'])
        self.assertEqual(result['dependent_features'], ['voice.c'])

    def test_invalid_paths_are_rejected_and_duplicates_are_deterministic(self):
        for path in ('../secret', '/etc/passwd', 'clients\\web\\x', 'C:/x', ''):
            with self.subTest(path=path), self.assertRaises(ValueError):
                analyze([path], self.catalog)
        self.assertEqual(analyze(['docs/x', 'docs/x'], self.catalog)['other_paths'], ['docs/x'])


if __name__ == '__main__':
    unittest.main()
