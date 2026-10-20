"""A failed owned controller exposes public source frames, never private log text."""
import unittest
from tools.qa.compatible_rollback.diagnostics import diagnose


class HarnessDiagnosticsTests(unittest.TestCase):
    def test_new_controller_frame_is_visible_while_private_guard_and_unknown_paths_are_removed(self):
        raw='''File "/qa-builder/tools/qa/trusted_delivery/interruption.py", line 81, in exercise
File "/Users/private-canary/credentials.py", line 2, in load
RuntimeError: private-canary
'''
        value=diagnose(raw,{'Known public guard'})
        self.assertEqual([dict(file='tools/qa/trusted_delivery/interruption.py',line=81,function='exercise')],value['frames'])
        self.assertEqual([],value['guard_messages'])
        self.assertNotIn('private-canary',str(value))
