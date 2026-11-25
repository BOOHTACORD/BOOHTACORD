"""Windows native QA must never exercise persistent user storage."""
import unittest
from unittest.mock import patch
from .native import main


class WindowsStartupTargets(unittest.TestCase):
    def test_only_scenarios_with_in_memory_storage_reach_device_verification(self):
        for target in ('issue689_roster_test.dart', 'startup_retry_test.dart'):
            with self.subTest(target=target), patch('sys.argv', [
                'native', '--platform', 'windows', '--device', 'windows',
                '--output', '.out/not-used', '--target', 'integration_test/' + target,
            ]), patch('tools.qa.local_features.native.verify_device',
                      side_effect=RuntimeError('device-verification-boundary')) as verify:
                with self.assertRaisesRegex(RuntimeError, 'device-verification-boundary'):
                    main()
                verify.assert_called_once_with('windows', 'windows')

    def test_persistent_storage_scenarios_are_rejected_before_device_access(self):
        for target in ('local_qa_test.dart', 'update_required_test.dart', '../unrelated.dart'):
            with self.subTest(target=target), patch('sys.argv', [
                'native', '--platform', 'windows', '--device', 'windows',
                '--output', '.out/not-used', '--target', 'integration_test/' + target,
            ]), patch('tools.qa.local_features.native.verify_device') as verify:
                with self.assertRaisesRegex(ValueError, 'in-memory storage'):
                    main()
                verify.assert_not_called()


if __name__ == '__main__':
    unittest.main()
