from pathlib import Path
import subprocess
import tempfile
import unittest
from .prepare import remove_generated


class PrepareTest(unittest.TestCase):
    def test_removes_only_untracked_generated_registrant(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            path = root/'clients/flutter/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'
            path.parent.mkdir(parents=True)
            path.write_text('// Generated file. Do not edit.\n')
            remove_generated(root)
            self.assertFalse(path.exists())
            path.write_text('// Generated file. Do not edit.\n')
            subprocess.run(['git', '-C', str(root), 'add', str(path)], check=True)
            with self.assertRaises(ValueError): remove_generated(root)
            self.assertTrue(path.exists())

    def test_preserves_unknown_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            path = root/'clients/flutter/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'
            path.parent.mkdir(parents=True); path.write_text('handwritten source')
            with self.assertRaises(ValueError): remove_generated(root)
            self.assertEqual(path.read_text(), 'handwritten source')
