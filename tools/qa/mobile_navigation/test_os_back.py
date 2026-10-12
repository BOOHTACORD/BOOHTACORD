"""Guard the OS-input helper from operating on a different worker's emulator."""
import unittest
from unittest.mock import patch
from .os_back import AndroidBackBridge


class AndroidBackOwnershipTest(unittest.TestCase):
    def test_other_worker_device_never_opens_input_bridge(self):
        with patch('subprocess.check_output', return_value='BOOHTACORD_QA_283_API35\nOK\n'), patch('tools.qa.mobile_navigation.os_back.ThreadingHTTPServer') as server:
            with self.assertRaises(ValueError):
                AndroidBackBridge('emulator-5554').__enter__()
            server.assert_not_called()

    def test_unassigned_AVD_never_opens_input_bridge(self):
        with patch('subprocess.check_output', return_value='other-AVD\nOK\n'), patch('tools.qa.mobile_navigation.os_back.ThreadingHTTPServer') as server:
            with self.assertRaises(ValueError):
                AndroidBackBridge('emulator-5556').__enter__()
            server.assert_not_called()


if __name__=='__main__':unittest.main()
