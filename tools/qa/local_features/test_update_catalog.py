import json
from pathlib import Path
import tempfile
import unittest

from .update_catalog import write_catalog


class UpdateCatalogTest(unittest.TestCase):
    def test_synthetic_catalog_covers_native_arches_and_uses_next_order(self):
        with tempfile.TemporaryDirectory() as directory:
            path = write_catalog(Path(directory), 67)
            data = json.loads(path.read_text(encoding='utf8'))
            self.assertEqual(len(data['entries']), 8)
            self.assertEqual({e['platform'] for e in data['entries']}, {'android', 'ios'})
            self.assertEqual({e['arch'] for e in data['entries']}, {'any','x64','arm64','armv7'})
            for entry in data['entries']:
                self.assertEqual(entry['target']['minimum_release_order'], 68)
                self.assertEqual(entry['target']['release_order'], 68)
                self.assertEqual(entry['distribution'], 'development')
                self.assertEqual(entry['channel'], 'development')

    def test_refuses_invalid_release_order(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                write_catalog(Path(directory), 0)
