import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from . import run


class NativeAdapterProbeTests(unittest.TestCase):
    def test_rejects_unverified_source_before_creating_output_or_running_tools(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'new-output'
            with patch.object(run, 'check_output'), \
                 patch.object(run, 'checked_source', side_effect=ValueError('unverified source')), \
                 patch.object(run.subprocess, 'run') as execute:
                with self.assertRaisesRegex(ValueError, 'unverified source'):
                    run.build(Path(directory), output, 'cmake', 'ctest')
            self.assertFalse(output.exists())
            execute.assert_not_called()

    def test_refuses_an_existing_output_before_running_tools(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            with patch.object(run, 'check_output'), patch.object(run, 'checked_source'), \
                 patch.object(run.subprocess, 'run') as execute:
                with self.assertRaises(FileExistsError):
                    run.build(output, output, 'cmake', 'ctest')
            execute.assert_not_called()


if __name__ == '__main__':
    unittest.main()
