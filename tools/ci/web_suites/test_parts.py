"""Only the complete bounded flat set of public JSON profile files is accepted."""
import json
from pathlib import Path
import tempfile
import unittest
from . import fan_in
from .test_fan_in import fixture


class PartFileTests(unittest.TestCase):
    def populate(self, directory):
        rows = fixture()[1]
        for row in rows: (directory / (row['profile'] + '.json')).write_text(json.dumps(row))
        return rows

    def test_complete_public_parts_can_be_read(self):
        with tempfile.TemporaryDirectory() as name:
            path = Path(name); rows = self.populate(path)
            self.assertEqual(sorted(fan_in.read_reports(path), key=lambda r: r['profile']),
                             sorted(rows, key=lambda r: r['profile']))

    def test_missing_extra_oversized_and_symlink_inputs_cannot_be_used(self):
        for change in ('missing', 'extra', 'oversized', 'symlink'):
            with tempfile.TemporaryDirectory() as name:
                path = Path(name); self.populate(path); target = path / 'fast.json'
                if change == 'missing': target.unlink()
                if change == 'extra': (path / 'unexpected.json').write_text('{}')
                if change == 'oversized': target.write_text('x' * 65537)
                if change == 'symlink':
                    target.unlink(); target.symlink_to(path / 'browser-shell.json')
                with self.subTest(change=change), self.assertRaises(ValueError):
                    fan_in.read_reports(path)

    def test_profile_identity_must_match_its_file_name(self):
        with tempfile.TemporaryDirectory() as name:
            path = Path(name); self.populate(path)
            fast, shell = path / 'fast.json', path / 'browser-shell.json'
            a, b = fast.read_bytes(), shell.read_bytes()
            fast.write_bytes(b); shell.write_bytes(a)
            with self.assertRaises(ValueError): fan_in.read_reports(path)
