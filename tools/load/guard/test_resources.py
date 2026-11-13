import unittest
from types import SimpleNamespace
from unittest.mock import patch

from tools.load.guard.resources import Resources
from tools.load.guard.sample_failure import SampleFailure


class ResourceSnapshotTests(unittest.TestCase):
    def test_measures_owned_api_container_from_private_metrics(self):
        stack = SimpleNamespace(api='qa-client-0123456789abcdef-api')
        snapshots = iter([
            {
                'process_cpu_seconds_total': 1.0,
                'process_resident_memory_bytes': 1024,
                'voice_platform_attachment_filesystem_available_bytes': 1 << 30,
            },
            {
                'process_cpu_seconds_total': 1.5,
                'process_resident_memory_bytes': 2048,
                'voice_platform_attachment_filesystem_available_bytes': 1 << 29,
            },
        ])
        with patch('tools.load.guard.resources.owned', return_value=stack.api) as owned, \
                patch('tools.load.guard.resources.snapshot', side_effect=lambda: next(snapshots)), \
                patch('tools.load.guard.resources.time.monotonic', side_effect=(10.0, 11.0)), \
                patch('tools.load.guard.resources.os.cpu_count', return_value=20), \
                patch('tools.load.guard.resources.output', return_value='2000000000'):
            resources = Resources(stack)
            first = resources.read()
            second = resources.read()

        owned.assert_called_with(stack, 'api')
        self.assertEqual(first, {'CPUPercent': 0, 'RSSBytes': 1024, 'FreeBytes': 1 << 30})
        self.assertEqual(second, {'CPUPercent': 25, 'RSSBytes': 2048, 'FreeBytes': 1 << 29})

    def test_refuses_missing_or_unbounded_cpu_quota(self):
        stack = SimpleNamespace(api='qa-client-0123456789abcdef-api')
        with patch('tools.load.guard.resources.owned', return_value=stack.api), \
                patch('tools.load.guard.resources.output', return_value='0'):
            with self.assertRaises(ValueError):
                Resources(stack).read()

    def test_metrics_failure_is_bounded_and_does_not_leak_details(self):
        stack = SimpleNamespace(api='qa-client-0123456789abcdef-api')
        with patch('tools.load.guard.resources.owned', return_value=stack.api), \
                patch('tools.load.guard.resources.output', return_value='2000000000'), \
                patch('tools.load.guard.resources.snapshot', side_effect=OSError('private details')):
            with self.assertRaises(SampleFailure) as failure:
                Resources(stack).read()
            self.assertEqual(str(failure.exception), 'resource_metrics')


if __name__ == '__main__':
    unittest.main()
