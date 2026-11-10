import tempfile
import unittest
from pathlib import Path

from tools.product_map.viewer.document import build_document, write_document


class DocumentTests(unittest.TestCase):
    def test_untrusted_data_cannot_close_script(self):
        output = build_document([{'id': '</script><script>alert(1)</script>',
                                  'group': 'voice', 'description': 'test',
                                  'issue': 688, 'platforms': {}}])
        self.assertNotIn('</script><script>alert(1)</script>', output)
        self.assertIn('Content-Security-Policy', output)
        self.assertEqual(output, build_document([{'id': '</script><script>alert(1)</script>',
                                                 'group': 'voice', 'description': 'test',
                                                 'issue': 688, 'platforms': {}}]))

    def test_check_detects_stale_output_without_modifying_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'index.html'
            self.assertFalse(write_document(path, 'new', check=True))
            self.assertTrue(write_document(path, 'old', check=False))
            self.assertFalse(write_document(path, 'new', check=True))
            self.assertEqual(path.read_text(encoding='utf-8'), 'old')
            self.assertTrue(write_document(path, 'new', check=False))
            self.assertTrue(write_document(path, 'new', check=True))
