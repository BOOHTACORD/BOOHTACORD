import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from . import run_native

class NativeRunnerTests(unittest.TestCase):
    def test_preflight_failure_cannot_reuse_old_pass(self):
        with tempfile.TemporaryDirectory() as t:
            output=Path(t)/'android';output.mkdir();(output/'runtime.json').write_text('{"status":"PASS"}');(output/'scenario.json').write_text('{"status":"PASS"}')
            with patch.object(run_native,'execute',side_effect=ValueError('fixture preflight')):
                with self.assertRaises(ValueError):run_native.run('android',output)
            report=json.loads((output/'runtime.json').read_text())
            self.assertEqual(report['status'],'FAIL')
            self.assertFalse((output/'scenario.json').exists())
            self.assertFalse(report['owned_resources_removed'])
    def test_reverse_partial_failure_attempts_all_owned_removals(self):
        calls=[]
        def action(args,**kwargs):
            calls.append(args[-1])
            if args[-1]=='tcp:4950':raise OSError()
        with patch.object(run_native.subprocess,'run',side_effect=action):
            errors=run_native.remove_reverses('emulator-5554',[4950,4991])
        self.assertEqual(calls,['tcp:4950','tcp:4991'])
        self.assertEqual(len(errors),1)
    def test_private_copy_preserves_product_build_directories(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t)/'repo';source=root/'clients/flutter';(source/'lib/feature/build').mkdir(parents=True)
            (source/'lib/feature/build/handler.dart').write_text('void main() {}')
            (source/'build').mkdir();(source/'build/private-app').write_text('compiled fixture')
            copy=Path(t)/'private'
            with patch.object(run_native,'ROOT',root),patch.object(run_native,'FLUTTER',copy):run_native.prepare()
            self.assertTrue((copy/'lib/feature/build/handler.dart').exists())
            self.assertFalse((copy/'build').exists())
