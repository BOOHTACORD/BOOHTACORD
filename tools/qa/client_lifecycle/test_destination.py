import tempfile
import unittest
from pathlib import Path

from .destination import fresh_capture_destination


class CaptureDestinationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()

    def test_relative_output_creates_a_separate_width_directory(self):
        result = fresh_capture_destination(self.root, '.out/new-run', 393)
        self.assertEqual(result, self.root / '.out/new-run/393')
        self.assertTrue(result.is_dir())

    def test_existing_receipt_is_never_overwritten(self):
        result = fresh_capture_destination(self.root, '.out/new-run', 393)
        receipt = result / 'report.json'
        receipt.write_text('original FAIL')
        with self.assertRaises(FileExistsError):
            fresh_capture_destination(self.root, '.out/new-run', 393)
        self.assertEqual(receipt.read_text(), 'original FAIL')

    def test_other_width_can_share_the_run_parent(self):
        first = fresh_capture_destination(self.root, '.out/new-run', 393)
        second = fresh_capture_destination(self.root, '.out/new-run', 1440)
        self.assertNotEqual(first, second)

    def test_paths_outside_ignored_output_are_rejected(self):
        for output in ['evidence/qa', '.out/../../outside', str(self.root.parent / 'outside')]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                fresh_capture_destination(self.root, output, 393)

    def test_output_symlink_cannot_escape_the_checkout(self):
        (self.root / '.out').mkdir()
        (self.root / '.out/escape').symlink_to(self.root.parent, target_is_directory=True)
        with self.assertRaises(ValueError):
            fresh_capture_destination(self.root, '.out/escape', 393)

    def test_width_is_validated_before_creating_output(self):
        with self.assertRaises(ValueError):
            fresh_capture_destination(self.root, '.out/new-run', 391)
        self.assertFalse((self.root / '.out/new-run').exists())


if __name__ == '__main__':
    unittest.main()
