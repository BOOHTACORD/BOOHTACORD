import json
import unittest
from pathlib import Path

from tools.product_map.projection.importer import import_parity


class RealRegistryTests(unittest.TestCase):
    def test_all_parity_ids_are_preserved(self):
        root = Path(__file__).resolve().parents[3]
        registry = json.loads((root / 'tools/qa/local_features/features.json')
                              .read_text(encoding='utf-8'))
        ids = {row['id'] for group in registry.values() for row in group['parity']}
        projected = import_parity(registry)
        self.assertEqual(ids, {row['id'] for row in projected})
        self.assertTrue(ids)
        self.assertTrue(all(len(row['platforms']) == 5 for row in projected))
