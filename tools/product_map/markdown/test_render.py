import unittest

from tools.product_map.markdown.render import render_feature, render_index


def feature():
    platforms = {p: {'source_status': 'UNKNOWN', 'released': 'UNKNOWN', 'runtime': 'NOT_VERIFIED',
                     'implemented_revision': None, 'target_revision': None}
                 for p in ('web', 'windows', 'macos', 'android', 'ios')}
    platforms['windows'].update(source_status='BEHIND', implemented_revision=2, target_revision=3)
    return {'id': 'auth.test', 'title': 'Тест', 'description': '<script>alert(1)</script>',
            'platforms': platforms, 'depends_on': ['auth.session'],
            'components': [{'id': 'cmp.backend.test', 'paths': ['backend/internal/test.go']}],
            'component_edges': []}


class MarkdownTests(unittest.TestCase):
    def test_index_links_feature_and_preserves_separate_statuses(self):
        output = render_index([feature()])
        self.assertIn('(features/auth.test.md)', output)
        self.assertIn('BEHIND', output)
        self.assertIn('r2 → r3', output)
        self.assertIn('UNKNOWN', output)
        self.assertEqual(output, render_index([feature()]))

    def test_feature_contains_safe_source_and_dependency_links(self):
        output = render_feature(feature())
        self.assertIn('../../../../backend/internal/test.go', output)
        self.assertIn('(auth.session.md)', output)
        self.assertNotIn('<script>', output)
        item = feature()
        item['components'][0]['paths'] = ['../../evil](javascript:alert(1))']
        output = render_feature(item)
        self.assertNotIn('](javascript:', output)

    def test_invalid_feature_id_cannot_create_paths_or_anchors(self):
        item = feature()
        item['id'] = '../../evil'
        with self.assertRaises(ValueError):
            render_index([item])

    def test_duplicate_feature_ids_cannot_overwrite_cards(self):
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            render_index([feature(), feature()])
