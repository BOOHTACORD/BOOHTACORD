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
        self.assertTrue(diagnose('Error response from daemon: Address already in use', set())['address_collision'])
        self.assertTrue(diagnose('dial failed: connection refused (SQLSTATE 57P03)', set())['tcp_not_ready'])
        self.assertEqual(diagnose('SQLSTATE 57P03', set())['sql_states'], ['57P03'])
        self.assertEqual(diagnose('File "/qa-builder/tools/build/server/smoke.py", line 50, in run_smoke', set())['frames'],
                         [{'file': 'tools/build/server/smoke.py', 'line': 50, 'function': 'run_smoke'}])

    def test_unapproved_paths_and_text_never_become_diagnostics(self):
        result = diagnose('File "/private/account-id", line 1, in secret\nFile "/private/tools/account-id.py", line 1, in secret\nFile "/qa/current/tools/../account-id.py", line 1, in secret\nsecret-cookie\n', set())
        self.assertEqual(result['frames'], [])
        self.assertEqual(result['guard_messages'], [])
        self.assertNotIn('account-id', str(result))


    def test_private_roomservice_probe_exports_only_known_codes_not_tokens_or_urls(self):
        text='LiveKit private path preflight failed: LiveKit private RoomService preflight failed (roomservice TimeoutError).\n'
        result=diagnose(text,set())
        self.assertEqual(result['livekit_probe_failures'],[{'phase':'roomservice','code':'TimeoutError'}])
        for injected in ('roomservice PRIVATE-CANARY HTTP 401','dns https://private.invalid/secret','roomservice TimeoutError HTTP 999'):
            result=diagnose('LiveKit private RoomService preflight failed ('+injected+')',set())
            self.assertEqual(result['livekit_probe_failures'],[])
            self.assertNotIn('PRIVATE-CANARY',str(result));self.assertNotIn('private.invalid',str(result))
