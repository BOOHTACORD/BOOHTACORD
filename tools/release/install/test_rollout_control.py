"""Unchanged signed schema inventories need no historical SQL replay."""
import copy
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from .rollout_control import prepare

BASH = shutil.which('bash')
if os.name == 'nt' and Path('C:/Program Files/Git/bin/bash.exe').is_file():
    BASH = 'C:/Program Files/Git/bin/bash.exe'
NEEDLE = '"${compose[@]}" run --rm --no-deps migrate'
SCRIPT = '#!/usr/bin/env bash\nset -euo pipefail\ncompose=(printf "MIGRATION_CALLED\\n")\n' + NEEDLE + '\n'


@unittest.skipUnless(BASH, 'Native Bash is required')
class RolloutControlTests(unittest.TestCase):
    def invoke(self, current, target, body=SCRIPT):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); source = root / 'signed-runtime'; source.mkdir()
            script = source / 'deploy-images.sh'; script.write_text(body, encoding='utf-8', newline='\n')
            sibling = source / 'helper.py'; sibling.write_text('public helper', encoding='utf-8')
            before = script.read_bytes(); work = root / 'private'; work.mkdir()
            selected = prepare(script, current, target, work)
            result = subprocess.run([BASH, selected.as_posix()], capture_output=True, text=True, check=True)
            self.assertEqual(script.read_bytes(), before)
            if selected != script: self.assertEqual((selected.parent / 'helper.py').read_bytes(), sibling.read_bytes())
            return result.stdout, selected != script

    def test_same_complete_inventory_skips_sql_without_editing_signed_runtime(self):
        manifest = {'compatibility': {'migrations': {'0001.sql': 'a' * 64}}}
        output, copied = self.invoke(manifest, copy.deepcopy(manifest))
        self.assertTrue(copied); self.assertNotIn('MIGRATION_CALLED', output)
        self.assertIn('no SQL applied', output)

    def test_new_changed_empty_or_unknown_inventory_keeps_actual_migration(self):
        current = {'compatibility': {'migrations': {'0001.sql': 'a' * 64}}}
        for target in ({'compatibility': {'migrations': {'0001.sql': 'b' * 64}}},
                       {'compatibility': {'migrations': {'0001.sql': 'a' * 64, '0002.sql': 'b' * 64}}},
                       {'compatibility': {'migrations': {}}}, {}, None):
            with self.subTest(target=target):
                output, copied = self.invoke(current, target)
                self.assertFalse(copied); self.assertIn('MIGRATION_CALLED', output)
        output, copied = self.invoke(None, current)
        self.assertFalse(copied); self.assertIn('MIGRATION_CALLED', output)
        empty = {'compatibility': {'migrations': {}}}
        output, copied = self.invoke(empty, empty)
        self.assertFalse(copied); self.assertIn('MIGRATION_CALLED', output)

    def test_unrecognized_historical_script_is_preserved(self):
        manifest = {'compatibility': {'migrations': {'0001.sql': 'a' * 64}}}
        output, copied = self.invoke(manifest, manifest, 'printf "historical-rollout\\n"\n')
        self.assertFalse(copied); self.assertEqual(output.strip(), 'historical-rollout')

    def test_indirect_runtime_is_rejected_before_copy_or_rollout(self):
        if os.name == 'nt': self.skipTest('Symlink creation requires a separate Windows privilege')
        manifest = {'compatibility': {'migrations': {'0001.sql': 'a' * 64}}}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); source = root / 'source'; source.mkdir()
            script = source / 'deploy-images.sh'; script.write_text(SCRIPT)
            (source / 'indirect').symlink_to(root / 'elsewhere')
            with self.assertRaises(ValueError): prepare(script, manifest, manifest, root / 'private')
