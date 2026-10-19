"""Operators can verify a real download and restore without trusting its manifest."""
import tempfile
import unittest
from pathlib import Path
from . import inspect, test_archive as fixtures
from .test_captures import identity


class CaptureInspectTests(unittest.TestCase):
    def arguments(self, root, path, digest, size):
        args = ['--archive', str(path), '--sha256', digest, '--bytes', str(size),
                '--output', str(root / 'downloaded'), '--restore', str(root / 'restored')]
        for key, value in identity().items():
            if key != 'repository': args += ['--' + key.replace('_', '-'), value]
        return args

    def test_external_exact_identity_and_zip_digest_restore_the_real_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); path, digest, size = fixtures.CaptureArchiveTests().fixture(root)
            self.assertEqual(0, inspect.main(self.arguments(root, path, digest, size)))
            self.assertTrue((root / 'restored/case/actual.png').is_file())

    def test_foreign_attempt_is_not_inferred_from_untrusted_downloaded_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); path, digest, size = fixtures.CaptureArchiveTests().fixture(root)
            args = self.arguments(root, path, digest, size); args[args.index('--run-attempt') + 1] = '2'
            self.assertEqual(1, inspect.main(args))
            self.assertFalse((root / 'downloaded').exists())
            self.assertFalse((root / 'restored').exists())

    def test_existing_restore_destination_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); path, digest, size = fixtures.CaptureArchiveTests().fixture(root)
            restored = root / 'restored'; restored.mkdir(); (restored / 'keep').write_text('unchanged')
            self.assertEqual(1, inspect.main(self.arguments(root, path, digest, size)))
            self.assertEqual('unchanged', (restored / 'keep').read_text())
