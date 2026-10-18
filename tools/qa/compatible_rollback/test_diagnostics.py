import unittest
from .diagnostics import diagnose


class DiagnosticsTests(unittest.TestCase):
    def test_only_public_guards_frames_and_numeric_failures_are_retained(self):
        result = diagnose('''  File "/qa/current/tools/build/server/images.py", line 51, in build
ValueError: Insufficient space
RuntimeError: private-password-and-message
ERROR: process did not complete successfully: exit code: 137
password=private-password-and-message
''', {'Insufficient space'})
        self.assertEqual(result['guard_messages'], ['Insufficient space'])
        self.assertEqual(result['frames'], [{'file': 'tools/build/server/images.py', 'line': 51, 'function': 'build'}])
        self.assertEqual(result['exit_codes'], [137])
        self.assertNotIn('private-password', str(result))

    def test_unapproved_paths_and_text_never_become_diagnostics(self):
        result = diagnose('File "/private/account-id", line 1, in secret\nFile "/private/tools/account-id.py", line 1, in secret\nFile "/qa/current/tools/../account-id.py", line 1, in secret\nsecret-cookie\n', set())
        self.assertEqual(result['frames'], [])
        self.assertEqual(result['guard_messages'], [])
        self.assertNotIn('account-id', str(result))
