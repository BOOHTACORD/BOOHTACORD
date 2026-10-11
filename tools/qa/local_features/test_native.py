import json
import unittest
from unittest.mock import patch
from .native import verify_device

class DeviceSafetyTests(unittest.TestCase):
    def test_android_rejects_physical_phone(self):
        with self.assertRaises(ValueError):verify_device('android','physical-device')
    def test_android_rejects_foreign_emulator(self):
        with patch('subprocess.check_output',return_value='Pixel_Production\nOK'):
            with self.assertRaises(ValueError):verify_device('android','emulator-5554')
    def test_ios_rejects_non_qa_simulator(self):
        inventory={'devices':{'ios':[{'udid':'id','name':'Personal iPhone','state':'Booted'}]}}
        with patch('subprocess.check_output',return_value=json.dumps(inventory)):
            with self.assertRaises(ValueError):verify_device('ios','id')

class ReverseOwnershipTests(unittest.TestCase):
    def test_existing_reverse_is_not_overwritten(self):
        from .native import reversed_ports
        with patch('subprocess.check_output',return_value='tcp:4810 tcp:4810\n'), patch('subprocess.run') as run:
            with self.assertRaises(ValueError):
                with reversed_ports('emulator-5554'):pass
            run.assert_not_called()
    def test_partial_setup_failure_removes_only_the_created_reverse(self):
        from .native import reversed_ports
        import subprocess
        with patch('subprocess.check_output',return_value=''), patch('subprocess.run',side_effect=[None,subprocess.CalledProcessError(1,'adb'),None]) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                with reversed_ports('emulator-5554'):pass
            self.assertEqual(run.call_args_list[-1].args[0],['adb','-s','emulator-5554','reverse','--remove','tcp:4810'])
