import csv
import json
import random
import tempfile
import unittest
from pathlib import Path

from .output import write_plan
from .trials import paired_trials


class BlindQualityOutputTest(unittest.TestCase):
    def test_separates_operator_key_from_listener_sheets(self):
        parent = Path(tempfile.mkdtemp())
        target = parent / 'plan'
        try:
            trials = paired_trials(['quiet'], ['v02'], 10, random.Random(5))
            write_plan(target, trials, 10)
            operator = json.loads((target / 'operator-private.json').read_text(encoding='utf-8'))
            self.assertEqual(operator, trials)
            with (target / 'listener-01.csv').open(encoding='utf-8', newline='') as file:
                rows = list(csv.DictReader(file))
            self.assertEqual(len(rows), 1)
            self.assertEqual(set(rows[0]), {'trial', 'preferred', 'speech_defect'})
            self.assertNotIn('v01', json.dumps(rows))
            with self.assertRaises(FileExistsError):
                write_plan(target, trials, 10)
        finally:
            if target.exists():
                for child in target.iterdir():
                    child.unlink()
                target.rmdir()
            parent.rmdir()

    def test_refuses_to_write_in_a_git_checkout(self):
        root = Path(__file__).resolve().parents[3]
        with self.assertRaisesRegex(ValueError, 'outside Git'):
            write_plan(root / '.out/blind-test-must-not-exist', [], 10)
