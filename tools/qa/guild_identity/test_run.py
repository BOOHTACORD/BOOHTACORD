"""The runner must stamp the tested checkout and propagate failed acceptance."""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch
from tools.qa.guild_identity import run


class RunnerReceiptTests(unittest.TestCase):
    def invoke(self, status):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name).resolve()
        location = root / 'tools/qa/guild_identity/run.py'
        location.parent.mkdir(parents=True)
        revision = ['a' * 40]
        destination = root / '.out/qa278/ios'

        def output(command, **options):
            if command == ['git', 'rev-parse', 'HEAD']:
                self.assertEqual(options['cwd'], root)
                return revision[0] + '\n'
            if command == ['flutter', '--version', '--machine']:
                return json.dumps({'frameworkVersion': '9.8.7',
                                   'dartSdkVersion': '8.7.6',
                                   'frameworkRevision': 'toolchain-revision'})
            raise AssertionError('Unexpected subprocess query')

        stack = MagicMock()
        stack.password = 'disposable-private-password'
        # An external checkout update while the test runs must not relabel it.
        stack.start.side_effect = lambda: revision.__setitem__(0, 'b' * 40)
        connection = MagicMock()
        context = MagicMock()
        context.wrap_socket.return_value.__enter__.return_value.getpeercert.return_value = b'public-test-certificate'

        def native(*args, **options):
            self.assertEqual(options['cwd'], root / 'clients/flutter')
            (destination / 'scenario.json').write_text(json.dumps({
                'status': status, 'platform': 'ios', 'os': 'actual native OS',
            }))

        with patch.object(run, '__file__', str(location)), \
             patch.object(sys, 'argv', ['qa', '--platform', 'ios', '--device', 'dedicated-qa']), \
             patch.dict(run.os.environ, {'BOOHTACORD_QA_SHARED_WORK': str(root / '.out')}), \
             patch.object(run, 'verify_device'), \
             patch.object(run, 'Stack', return_value=stack), \
             patch.object(run.subprocess, 'check_output', side_effect=output), \
             patch.object(run.socket, 'create_connection', return_value=connection), \
             patch.object(run.ssl, '_create_unverified_context', return_value=context), \
             patch.object(run, 'run_owned', side_effect=native):
            run.main()
        stack.close.assert_called_once()
        return json.loads((destination / 'runtime.json').read_text())

    def test_receipt_uses_checkout_before_stack_start_and_current_toolchain(self):
        receipt = self.invoke('PASS')
        self.assertEqual(receipt['candidate'], 'a' * 40)
        self.assertEqual(receipt['flutter'], '9.8.7')
        self.assertEqual(receipt['dart'], '8.7.6')
        self.assertEqual(receipt['os'], 'actual native OS')
        self.assertTrue(receipt['owned_resources_removed'])

    def test_failed_native_status_cannot_exit_successfully(self):
        with self.assertRaisesRegex(RuntimeError, 'did not pass'):
            self.invoke('FAIL')


if __name__ == '__main__':
    unittest.main()
