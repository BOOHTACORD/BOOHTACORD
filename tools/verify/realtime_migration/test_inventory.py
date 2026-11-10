import json
import unittest
from pathlib import Path

from tools.verify.realtime_migration.guard import ROOT


class MigrationInventoryTest(unittest.TestCase):
    def test_every_entry_has_a_unique_path_and_verifiable_disposition(self):
        inventory = json.loads((Path(__file__).with_name('inventory.json')).read_text(encoding='utf8'))
        self.assertEqual(inventory['baseline_revision'], '10e0e44f28a2612d2f7fecf5be06931cf91fb166')
        entries = inventory['entries']
        self.assertTrue(entries)
        self.assertEqual(len(entries), len({entry['path'] for entry in entries}))
        for entry in entries:
            with self.subTest(path=entry['path']):
                self.assertTrue(all(entry.get(key) for key in ('owner', 'purpose', 'replacement', 'evidence')))
                self.assertTrue((ROOT / entry['evidence']).is_file())
                self.assertIn(entry['outcome'], ('retired', 'rewired', 'renamed_non_sse'))
                self.assertEqual((ROOT / entry['path']).exists(), entry['outcome'] != 'retired')


if __name__ == '__main__':
    unittest.main()
