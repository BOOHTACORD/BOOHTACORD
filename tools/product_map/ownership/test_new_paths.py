import unittest

from tools.product_map.ownership.new_paths import classify_new_paths


class OwnershipTests(unittest.TestCase):
    def setUp(self):
        self.catalog = {'components': [{'id': 'cmp.voice',
                         'paths': ['backend/internal/voice/new.go']}],
                        'features': [{'id': 'voice.a', 'components': ['cmp.voice']}]}

    def test_existing_unmapped_is_baseline_new_mapped_is_allowed(self):
        old = ['backend/internal/voice/legacy.go']
        new = old + ['backend/internal/voice/new.go']
        self.assertEqual(classify_new_paths(old, new, self.catalog), [])

    def test_new_unmapped_runtime_path_fails_even_when_existing_path_removed(self):
        old = ['backend/internal/voice/legacy.go']
        new = ['backend/internal/voice/renamed.go']
        self.assertEqual(classify_new_paths(old, new, self.catalog),
                         ['backend/internal/voice/renamed.go'])

    def test_docs_and_test_files_are_not_runtime_entries(self):
        new = ['docs/guide.md', 'backend/internal/voice/service_test.go',
               'clients/web/src/voice/voice.test.ts', 'clients/web/src/voice/new.ts']
        self.assertEqual(classify_new_paths([], new, self.catalog),
                         ['clients/web/src/voice/new.ts'])

    def test_multiple_owners_are_allowed_but_parent_prefix_is_not_a_file_mapping(self):
        data = {'components': [{'id': 'cmp.a', 'paths': ['clients/web/src/voice']},
                               {'id': 'cmp.b', 'paths': ['clients/web/src/voice.ts']},
                               {'id': 'cmp.c', 'paths': ['clients/web/src/voice.ts']}],
                'features': [{'id': 'voice.a', 'components': ['cmp.a', 'cmp.b', 'cmp.c']}]}
        paths = ['clients/web/src/voice.ts', 'clients/web/src/voice/missing.ts']
        self.assertEqual(classify_new_paths([], paths, data), ['clients/web/src/voice/missing.ts'])

    def test_new_platform_adapters_do_not_evade_ownership(self):
        paths = ['clients/flutter/windows/runner/new.cpp',
                 'clients/flutter/android/app/src/main/kotlin/New.kt',
                 'clients/flutter/ios/Runner/New.swift', 'clients/flutter/macos/Runner/New.swift']
        self.assertEqual(classify_new_paths([], paths, self.catalog), sorted(paths))

    def test_directory_named_tests_does_not_hide_production_helpers(self):
        path = 'clients/web/src/tests/helper.ts'
        self.assertEqual(classify_new_paths([], [path], self.catalog), [path])

    def test_orphan_component_does_not_count_as_feature_ownership(self):
        self.catalog['features'][0]['components'] = []
        path = 'backend/internal/voice/new.go'
        self.assertEqual(classify_new_paths([], [path], self.catalog), [path])

    def test_dependency_of_feature_component_counts_as_ownership(self):
        self.catalog['components'].append({'id': 'cmp.db', 'paths': ['backend/internal/db/new.go']})
        self.catalog['components'][0]['depends_on'] = ['cmp.db']
        self.assertEqual(classify_new_paths([], ['backend/internal/db/new.go'], self.catalog), [])
