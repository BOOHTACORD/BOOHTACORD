import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import Mock

from tools.qa.local_features.android_back.exercise import android_back_on_capture


class AndroidBackTests(unittest.TestCase):
    def test_sends_one_back_only_after_fresh_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'android-required-update.png'
            called = threading.Event()
            runner = Mock(side_effect=lambda *args, **kwargs: called.set())
            with android_back_on_capture('android', 'emulator-5554',
                                         'integration_test/update_required_test.dart',
                                         Path(directory), runner=runner, timeout=2):
                self.assertFalse(called.is_set())
                marker.write_bytes(b'capture')
                self.assertTrue(called.wait(1))
            runner.assert_called_once_with(
                ['adb', '-s', 'emulator-5554', 'shell', 'input', 'keyevent', 'KEYCODE_BACK'],
                check=True, timeout=10,
            )

    def test_rejects_stale_capture_and_missing_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'android-required-update.png'
            marker.write_bytes(b'old')
            with self.assertRaises(ValueError):
                with android_back_on_capture('android', 'emulator-5554',
                                             'integration_test/update_required_test.dart', Path(directory)):
                    pass
            marker.unlink()
            with self.assertRaises(RuntimeError):
                with android_back_on_capture('android', 'emulator-5554',
                                             'integration_test/update_required_test.dart', Path(directory), timeout=0.1):
                    pass

    def test_adb_failure_fails_the_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'android-required-update.png'
            runner = Mock(side_effect=OSError('synthetic adb failure'))
            with self.assertRaises(RuntimeError):
                with android_back_on_capture('android', 'emulator-5554',
                                             'integration_test/update_required_test.dart',
                                             Path(directory), runner=runner, timeout=2):
                    marker.write_bytes(b'capture')

    def test_other_targets_do_not_send_keys(self):
        runner = Mock()
        with android_back_on_capture('ios', 'simulator', 'integration_test/update_required_test.dart',
                                     Path('.'), runner=runner):
            pass
        runner.assert_not_called()

    def test_rejects_non_emulator_device(self):
        with self.assertRaises(ValueError):
            with android_back_on_capture('android', 'physical-device',
                                         'integration_test/update_required_test.dart', Path('.')):
                pass


if __name__ == '__main__':
    unittest.main()
