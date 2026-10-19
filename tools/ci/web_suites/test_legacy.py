"""The measured control must execute verified original code and every command."""
import hashlib
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from . import catalog, legacy

SOURCE = 'a' * 40


class LegacyTests(unittest.TestCase):
    def test_reference_source_digest_is_checked_before_execution(self):
        with self.assertRaises(ValueError): legacy.load_original(reader=lambda *a,**k: b'not the reference')
        body = b'def main():\n    return 42\n'
        spec = {**catalog.baseline(), 'source_sha256':hashlib.sha256(body).hexdigest()}
        with patch.object(catalog, 'baseline', return_value=spec):
            value = legacy.load_original(reader=lambda *a,**k: body)
            self.assertEqual(value['main'](), 42)

    def boundary(self, missing=False, fail=False):
        calls, space = [], {}
        operations = catalog.baseline()['operations']
        def main():
            space['run']('npm','ci',cwd=legacy.client('web'))
            for name, operation in operations.items():
                if missing and name == 'npm:test:accessibility': continue
                args = [legacy.sys.executable if a=='{python}' else a for a in operation['command']]
                options = {'cwd':legacy.client('web') if operation['cwd']=='web' else legacy.ROOT}
                if operation['smoke_env']:
                    options['env']={'SCREEN_SHARE_SFU_URL':'ws://127.0.0.1:17880', 'SCREEN_SHARE_SFU_IMAGE':legacy.IMAGE}
                space['run'](*args,**options)
        def execute(*command,**options):
            calls.append(command)
            return SimpleNamespace(returncode=1 if fail and 'test:accessibility' in command else 0)
        space['main']=main
        ticks=iter((1.0,2.0))
        return calls,dict(executor=execute,loader=lambda:space,clock=lambda:next(ticks))

    def test_control_executes_the_original_order_with_the_original_two_installs(self):
        calls,options=self.boundary();r=legacy.run_legacy(SOURCE,**options)
        self.assertEqual(r['status'],'PASS')
        self.assertEqual(r['operations'],list(catalog.baseline()['operations']))
        self.assertEqual(calls.count(('npm','ci')),2)

    def test_missing_or_failed_original_check_cannot_create_a_control_pass(self):
        for key in ('missing','fail'):
            calls,options=self.boundary(**{key:True})
            with self.subTest(key=key),self.assertRaises((ValueError,RuntimeError)):
                legacy.run_legacy(SOURCE,**options)
