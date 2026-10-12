"""Failure-path ownership of this worker's Android reverse ports."""
import subprocess
import json
import sys
import tempfile
from pathlib import Path
import unittest
from unittest.mock import call, patch

from . import run_native


class ReverseCleanupTests(unittest.TestCase):
    def test_second_install_failure_retains_only_successfully_owned_port(self):
        created = []
        with patch.object(run_native.subprocess, 'run', side_effect=[None, subprocess.CalledProcessError(1, ['adb'])]) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                run_native.install_reverses('emulator-5556', (4840, 4844, 4893), created)
        self.assertEqual(created, [4840])
        self.assertEqual(run.call_count, 2)
        with patch.object(run_native.subprocess, 'run') as remove:
            errors = run_native.remove_reverses('emulator-5556', created)
        self.assertEqual(errors, [])
        remove.assert_called_once_with(['adb', '-s', 'emulator-5556', 'reverse', '--remove', 'tcp:4840'], check=True, stdout=subprocess.DEVNULL)

    def test_first_remove_failure_still_attempts_every_owned_port(self):
        with patch.object(run_native.subprocess, 'run', side_effect=[subprocess.CalledProcessError(1, ['adb']), None, None]) as run:
            errors = run_native.remove_reverses('emulator-5556', [4840, 4844, 4893])
        self.assertEqual(errors, [{'port': 4840, 'error_type': 'CalledProcessError'}])
        self.assertEqual(run.call_args_list, [call(['adb', '-s', 'emulator-5556', 'reverse', '--remove', f'tcp:{port}'], check=True, stdout=subprocess.DEVNULL) for port in (4840, 4844, 4893)])

    def test_main_second_install_failure_writes_failure_receipt_after_cleanup(self):
        names = ['src/screens/profile_screen.dart', 'src/screens/workspace_ui/workspace_screen/build/back_guard/handler.dart', 'src/screens/workspace_ui/workspace_screen/build/swipe_navigation/handler.dart', 'src/screens/workspace_ui/workspace_screen/build/mobile_layers/handler.dart', 'src/screens/workspace_ui/main_surface/build/handler.dart', 'src/screens/workspace_ui/workspace_screen/close_drawers/handler.dart', 'src/widgets/sliding_drawer_layer.dart', 'src/features/workspace/search/navigation.dart', 'src/features/voice/admission/join.dart', 'src/features/workspace/mobile_navigation/top.dart']
        def output(command, **kwargs):
            if command[:3] == ['git', 'diff', '--binary']:
                return b'owned test diff'
            if 'getprop' in command:
                return '15'
            if 'reverse' in command:
                return ''
            return 'test-candidate'
        for cleanup_fails in (False, True):
            with self.subTest(cleanup_fails=cleanup_fails), tempfile.TemporaryDirectory() as directory:
                fake_file = str(Path(directory)/'tools/qa/mobile_navigation/run_native.py')
                removal = subprocess.CalledProcessError(1, ['adb']) if cleanup_fails else None
                with patch.object(run_native, '__file__', fake_file), patch.object(sys, 'argv', ['qa', '--platform', 'android', '--device', 'emulator-5556']), patch.object(run_native, 'verify_device'), patch.object(run_native, 'source_manifest', return_value={n: 'digest' for n in names}), patch.object(run_native, 'digest', return_value='digest'), patch.object(run_native.subprocess, 'check_output', side_effect=output), patch.object(run_native.subprocess, 'run', side_effect=[None, subprocess.CalledProcessError(1, ['adb']), removal]) as run, patch.object(run_native, 'Stack') as stack:
                    with self.assertRaises(RuntimeError if cleanup_fails else subprocess.CalledProcessError):
                        run_native.main()
                stack.assert_not_called()
                receipt = json.loads((Path(directory)/'.out/qa292-20261012/android/runtime.json').read_text())
                self.assertEqual(receipt['status'], 'FAIL')
                self.assertEqual(receipt['owned_reverse_removed'], not cleanup_fails)
                self.assertEqual(receipt['owned_resources_removed'], not cleanup_fails)
                self.assertEqual(receipt['owned_reverse_ports_created'], [4840])
                self.assertEqual(receipt['reverse_cleanup_errors'], [{'port': 4840, 'error_type': 'CalledProcessError'}] if cleanup_fails else [])
                self.assertEqual(run.call_args_list[-1], call(['adb', '-s', 'emulator-5556', 'reverse', '--remove', 'tcp:4840'], check=True, stdout=subprocess.DEVNULL))

    def test_cleanup_does_not_remove_uncreated_or_foreign_ports(self):
        with patch.object(run_native.subprocess, 'run') as run:
            self.assertEqual(run_native.remove_reverses('emulator-5556', []), [])
        run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
