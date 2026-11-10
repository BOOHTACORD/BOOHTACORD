import unittest

from tools.product_map.projection.render import render_matrix


class RenderTests(unittest.TestCase):
    def test_escapes_untrusted_content_and_keeps_unknown_visible(self):
        feature = {'id': 'x<unsafe>|y', 'description': '<script>alert(1)</script>',
                   'platforms': {name: {'source_status': 'UNKNOWN',
                                       'released': 'UNKNOWN',
                                       'runtime': 'NOT_VERIFIED'}
                                 for name in ('web', 'windows', 'macos', 'android', 'ios')}}
        output = render_matrix([feature])
        self.assertNotIn('<script>', output)
        self.assertIn('&lt;script&gt;', output)
        self.assertIn('UNKNOWN', output)
        self.assertEqual(output, render_matrix([feature]))

    def test_markdown_links_do_not_become_active(self):
        feature = {'id': 'x', 'description': '[click](javascript:alert)',
                   'platforms': {name: {'source_status': 'UNKNOWN',
                                       'released': 'UNKNOWN',
                                       'runtime': 'NOT_VERIFIED'}
                                 for name in ('web', 'windows', 'macos', 'android', 'ios')}}
        self.assertNotIn('[click](javascript:alert)', render_matrix([feature]))
