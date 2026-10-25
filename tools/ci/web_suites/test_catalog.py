"""Dropping, duplicating or redirecting original Web checks must fail before CI."""
import copy
import json
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch
from . import catalog

ROOT = Path(__file__).resolve().parents[3]


class CoverageTests(unittest.TestCase):
    def scripts(self):
        return json.loads((ROOT / 'clients/web/package.json').read_text())['scripts']

    def test_reviewed_plan_preserves_unit_build_accessibility_and_real_sfu(self):
        plan = catalog.plan()
        catalog.validate(plan, self.scripts())
        operations = {item for names in plan['profiles'].values() for item in names}
        for name in ('npm:test', 'npm:build', 'npm:verify:social-preview',
                     'npm:test:accessibility', 'npm:test:screen-profile-sfu',
                     'npm:test:audio:browser', 'python:tools.network.restricted.run',
                     'python:tools.audio.native_tests.run'):
            self.assertIn(name, operations)
        self.assertEqual(set(plan['profiles']),
                         {'fast', 'browser-shell', 'browser-content', 'browser-conversations', 'browser-voice', 'sfu-network'})

    def test_shell_split_preserves_original_checks_and_notification_suite_exactly_once(self):
        plan = catalog.plan()
        self.assertEqual(['npm:test:accessibility', 'npm:test:responsive-shell', 'npm:test:controls'],
                         plan['profiles']['browser-shell'])
        self.assertEqual(['npm:test:microcopy', 'npm:test:chat-rhythm',
                          'npm:test:message-social', 'npm:test:navigation'],
                         plan['profiles']['browser-content'])
        operations = [op for group in plan['profiles'].values() for op in group]
        self.assertEqual(41, len(operations))
        self.assertIn("npm:test:notifications", plan["profiles"]["browser-conversations"])
        self.assertEqual(41, len(set(operations)))

    def test_missing_duplicate_unknown_and_changed_command_are_rejected(self):
        for change in ('missing', 'duplicate', 'unknown', 'redirect'):
            value = copy.deepcopy(catalog.plan())
            name = 'npm:test:accessibility'
            owner = next(items for items in value['profiles'].values() if name in items)
            if change == 'missing': owner.remove(name)
            if change == 'duplicate': owner.append(name)
            if change == 'unknown': owner.append('npm:unreviewed')
            if change == 'redirect': value['operations'][name]['command'] = ['true']
            with self.subTest(change=change), self.assertRaises(ValueError):
                catalog.validate(value, self.scripts())

    def test_package_script_drift_and_new_unclassified_suites_fail_closed(self):
        for change in ('new', 'modified', 'missing'):
            scripts = self.scripts()
            if change == 'new': scripts['test:new-critical-flow'] = 'playwright test new.spec.ts'
            if change == 'modified': scripts['test:accessibility'] = 'echo omitted'
            if change == 'missing': scripts.pop('test:screen-profile-sfu')
            with self.subTest(change=change), self.assertRaises(ValueError):
                catalog.validate(catalog.plan(), scripts)

    def test_reviewed_new_suite_can_be_added_without_rewriting_the_historical_baseline(self):
        value, scripts = catalog.plan(), self.scripts()
        scripts['test:new-critical-flow'] = 'playwright test new.spec.ts'
        value['script_inventory'] = scripts = {k:v for k,v in scripts.items()
                                              if k.startswith('test') or k in ('build','verify:social-preview')}
        name = 'npm:test:new-critical-flow'
        value['operations'][name] = {'command':['npm','run','test:new-critical-flow'],
                                     'cwd':'web','sfu':False,'smoke_env':False}
        value['profiles']['browser-conversations'].append(name)
        catalog.validate(value, scripts)

    def test_windows_crlf_checkout_keeps_the_same_reviewed_baseline_identity(self):
        original = catalog.baseline()
        data = (catalog.DIRECTORY / 'baseline-v1.json').read_bytes().replace(b'\r\n', b'\n')
        with tempfile.TemporaryDirectory() as name:
            path = Path(name); (path / 'baseline-v1.json').write_bytes(data.replace(b'\n', b'\r\n'))
            with patch.object(catalog, 'DIRECTORY', path):
                self.assertEqual(catalog.baseline(), original)
