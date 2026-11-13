import tempfile
import unittest
from pathlib import Path

from tools.product_map.markdown.output import write_markdown
from tools.product_map.markdown.test_render import feature


class MarkdownOutputTests(unittest.TestCase):
    def test_generation_check_and_stale_detection(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertFalse(write_markdown(root, [feature()], check=True))
            self.assertTrue(write_markdown(root, [feature()], check=False))
            self.assertTrue(write_markdown(root, [feature()], check=True))
            (root / 'features/auth.test.md').write_text('stale', encoding='utf-8')
            self.assertFalse(write_markdown(root, [feature()], check=True))
            self.assertTrue(write_markdown(root, [feature()], check=False))
            self.assertTrue(write_markdown(root, [feature()], check=True))

    def test_orphan_generated_feature_is_not_silently_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertTrue(write_markdown(root, [feature()], check=False))
            (root / 'features/old.md').write_text('old', encoding='utf-8')
            self.assertFalse(write_markdown(root, [feature()], check=True))
            with self.assertRaisesRegex(ValueError, 'orphan'):
                write_markdown(root, [feature()], check=False)

    def test_symlinked_feature_directory_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp, tempfile.TemporaryDirectory() as outside:
            root = Path(tmp)
            try:
                (root / 'features').symlink_to(outside, target_is_directory=True)
            except OSError as error:
                self.skipTest(f'symlink creation unavailable: {error}')
            with self.assertRaisesRegex(ValueError, 'symlink'):
                write_markdown(root, [feature()], check=False)
