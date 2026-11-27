from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from tools.qa.client_lifecycle.background_fault.run import arguments, fresh_output


class RunBoundaryTest(unittest.TestCase):
    def test_physical_or_injected_device_selector_is_rejected(self):
        for device in ('phone', 'emulator-5580;whoami', 'host:5555'):
            with self.subTest(device=device), self.assertRaises(ValueError):
                arguments(['--device', device, '--role', 'api', '--output', '.out/test'])

    def test_existing_output_is_preserved(self):
        with TemporaryDirectory() as work:
            output = Path(work)/'result'; output.mkdir()
            marker = output/'original.txt'; marker.write_text('preserve')
            with self.assertRaises(FileExistsError): fresh_output(output)
            self.assertEqual(marker.read_text(), 'preserve')

    def test_new_output_gets_its_own_directory(self):
        with TemporaryDirectory() as work:
            output = fresh_output(Path(work)/'new'/'result')
            self.assertTrue(output.is_dir())
            self.assertEqual(list(output.iterdir()), [])
