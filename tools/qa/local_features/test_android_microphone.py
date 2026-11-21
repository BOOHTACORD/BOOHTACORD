import time
import unittest
from unittest.mock import patch

from .android_microphone import android_microphone_permission


class AndroidMicrophoneTests(unittest.TestCase):
    def test_grant_is_scoped_to_registered_android_capture(self):
        with patch('subprocess.run') as run:
            with android_microphone_permission('android', 'emulator-5554',
                    'integration_test/android_noise_sfu_test.dart'):
                for _ in range(50):
                    if run.called:
                        break
                    time.sleep(.01)
            self.assertTrue(run.called)
            self.assertEqual(run.call_args.args[0], [
                'adb', '-s', 'emulator-5554', 'shell', 'pm', 'grant',
                'ru.boohtacord.app', 'android.permission.RECORD_AUDIO'])

    def test_grant_is_scoped_to_issue785_paired_microphone_capture(self):
        with patch('subprocess.run') as run:
            with android_microphone_permission('android', 'emulator-5554',
                    'integration_test/issue785_background_microphone_uplink_test.dart'):
                for _ in range(50):
                    if run.called:
                        break
                    time.sleep(.01)
            self.assertTrue(run.called)
            self.assertEqual(run.call_args.args[0], [
                'adb', '-s', 'emulator-5554', 'shell', 'pm', 'grant',
                'ru.boohtacord.app', 'android.permission.RECORD_AUDIO'])

    def test_other_targets_do_not_grant_and_physical_devices_are_rejected(self):
        with patch('subprocess.run') as run:
            with android_microphone_permission('android', 'emulator-5554',
                    'integration_test/local_qa_test.dart'):
                pass
            run.assert_not_called()
        with self.assertRaises(ValueError):
            with android_microphone_permission('android', 'physical-phone',
                    'integration_test/android_noise_sfu_test.dart'):
                pass
