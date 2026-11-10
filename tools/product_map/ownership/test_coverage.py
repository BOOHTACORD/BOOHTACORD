import unittest
from pathlib import Path
from unittest.mock import patch

from tools.product_map.ownership.coverage import coverage_report
from tools.product_map.ownership.report import report


class CoverageTests(unittest.TestCase):
    def test_counts_unique_tracked_paths_and_separates_unmapped(self):
        catalog = {'components': [{'id': 'cmp.a', 'paths': ['backend/internal/a.go']},
                                  {'id': 'cmp.orphan', 'paths': ['backend/internal/b.go']}],
                   'features': [{'id': 'feature.a', 'components': ['cmp.a']}]}
        paths = ['backend/internal/a.go', 'backend/internal/a.go', 'backend/internal/b.go',
                 'backend/internal/a_test.go', 'clients/flutter/windows/new.cpp', 'docs/a.md']
        result = coverage_report(paths, catalog)
        self.assertEqual(result['status'], 'INCOMPLETE')
        self.assertEqual(result['total'], 3)
        self.assertEqual(result['mapped'], 1)
        self.assertEqual(result['unmapped'], 2)
        self.assertEqual(result['groups']['backend/internal/']['unmapped_sample'],
                         ['backend/internal/b.go'])
        self.assertEqual(result['groups']['clients/flutter/windows/']['unmapped'], 1)

    def test_sample_is_bounded_and_deterministic(self):
        catalog = {'features': [], 'components': []}
        paths = [f'clients/web/src/{n:02}.ts' for n in range(15)]
        first = coverage_report(list(reversed(paths)), catalog)
        self.assertEqual(first, coverage_report(paths, catalog))
        self.assertEqual(first['unmapped'], 15)
        self.assertEqual(len(first['groups']['clients/web/src/']['unmapped_sample']), 10)

    def test_feature_scope_counts_only_its_owned_tree(self):
        catalog = {'features': [{'id': 'auth.registration', 'components': ['cmp.reg'],
                                 'owned_roots': [{'path': 'backend/internal/identity/register_user/',
                                                  'component': 'cmp.reg'}]}],
                   'components': [{'id': 'cmp.reg', 'paths': ['backend/internal/identity/register_user/service.go']}]}
        result = coverage_report(['backend/internal/identity/register_user/service.go',
                                  'backend/internal/identity/other/service.go'], catalog)
        self.assertEqual((result['mapped'], result['unmapped']), (1, 1))

    @patch('tools.product_map.ownership.report.subprocess.run')
    def test_dirty_catalog_cannot_be_attributed_to_head(self, git):
        git.return_value.stdout = b' M product-map/features/voice/core.yaml\n'
        with self.assertRaisesRegex(ValueError, 'differs from HEAD'):
            report(Path('.'))
