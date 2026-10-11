import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from .doctor import boot_android

class BootstrapTests(unittest.TestCase):
    def test_does_not_boot_an_unrelated_avd(self):
        with tempfile.TemporaryDirectory() as t, patch('tools.qa.local_features.doctor.probe',return_value='Personal_Pixel'), patch('subprocess.Popen') as spawn:
            self.assertIsNone(boot_android(Path(t)/'emulator.log'))
            spawn.assert_not_called()
    def test_boots_only_the_named_qa_device_without_snapshots(self):
        with tempfile.TemporaryDirectory() as t, patch('tools.qa.local_features.doctor.probe',return_value='Personal_Pixel\nBOOHTACORD_QA_API35'), patch('tools.qa.local_features.doctor.devices',return_value={'android':'emulator-5554'}), patch('subprocess.Popen') as spawn:
            self.assertEqual(boot_android(Path(t)/'emulator.log'),'emulator-5554')
            command=spawn.call_args[0][0]
            self.assertEqual(command[command.index('-avd')+1],'BOOHTACORD_QA_API35')
            self.assertIn('-no-snapshot',command)
