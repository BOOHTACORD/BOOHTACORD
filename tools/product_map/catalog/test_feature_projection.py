import unittest

from tools.product_map.catalog.feature_projection import project_feature


def feature():
    return {'id': 'voice.a', 'title': 'Voice', 'domain': 'voice', 'target_revision': 3,
            'parity_ids': ['voice.a'], 'platforms': {
                'web': {'applicability': 'SUPPORTED', 'state': 'IMPLEMENTED', 'revision': 3},
                'windows': {'applicability': 'SUPPORTED', 'state': 'IMPLEMENTED', 'revision': 2},
                'macos': {'applicability': 'SUPPORTED', 'state': 'NOT_STARTED', 'revision': None},
                'android': {'applicability': 'UNKNOWN', 'state': 'UNKNOWN', 'revision': None},
                'ios': {'applicability': 'UNKNOWN', 'state': 'UNKNOWN', 'revision': None}}}


class FeatureProjectionTests(unittest.TestCase):
    def test_source_revision_is_independent_from_release_and_runtime(self):
        row = {'id': 'voice.a', 'description': 'Existing scenario', 'platforms': {
            'web': {'released': 'UNKNOWN', 'runtime': 'NOT_VERIFIED', 'tests': ['test.ts']}}}
        result = project_feature(feature(), row)
        self.assertEqual(result['platforms']['web']['source_status'], 'IN_SYNC')
        self.assertEqual(result['platforms']['windows']['source_status'], 'BEHIND')
        self.assertEqual(result['platforms']['macos']['source_status'], 'MISSING')
        self.assertEqual(result['platforms']['windows']['implemented_revision'], 2)
        self.assertEqual(result['platforms']['windows']['target_revision'], 3)
        self.assertEqual(result['platforms']['web']['tests'], ['test.ts'])
        for platform in result['platforms'].values():
            self.assertEqual(platform['released'], 'UNKNOWN')
            self.assertEqual(platform['runtime'], 'NOT_VERIFIED')

    def test_catalog_only_feature_is_visible_on_five_platforms(self):
        item = feature()
        item['parity_ids'] = []
        item['depends_on'] = ['auth.session']
        result = project_feature(item)
        self.assertEqual(result['id'], 'voice.a')
        self.assertEqual(result['group'], 'voice')
        self.assertEqual(len(result['platforms']), 5)
        self.assertEqual(result['platforms']['windows']['source_status'], 'BEHIND')
        self.assertEqual(result['platforms']['windows']['runtime'], 'NOT_VERIFIED')
        self.assertEqual(result['depends_on'], ['auth.session'])

    def test_exception_without_approval_does_not_become_green(self):
        item = feature()
        item['platforms']['ios']['applicability'] = 'PLATFORM_EXCEPTION'
        result = project_feature(item)
        self.assertEqual(result['platforms']['ios']['source_status'], 'UNKNOWN')
