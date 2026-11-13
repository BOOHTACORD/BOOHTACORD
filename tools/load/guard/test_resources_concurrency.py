import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
from unittest.mock import patch

from tools.load.guard.resources import Resources


class ConcurrentResourcesTests(unittest.TestCase):
    def test_same_timestamp_is_rejected_without_dividing_by_zero(self):
        stack = SimpleNamespace(api='qa-client-0123456789abcdef-api')
        values = {'process_cpu_seconds_total': 1.0,
                  'process_resident_memory_bytes': 1024,
                  'voice_platform_attachment_filesystem_available_bytes': 1 << 30}
        with patch('tools.load.guard.resources.owned', return_value=stack.api), \
                patch('tools.load.guard.resources.output', return_value='2000000000'), \
                patch('tools.load.guard.resources.snapshot', return_value=values), \
                patch('tools.load.guard.resources.time.monotonic', return_value=10):
            resources = Resources(stack)
            resources.read()
            with self.assertRaises(ValueError):
                resources.read()

    def test_cpu_snapshots_cannot_overlap_and_reorder_the_previous_sample(self):
        stack = SimpleNamespace(api='qa-client-0123456789abcdef-api')
        start = threading.Barrier(2)
        lock = threading.Lock()
        active = 0
        maximum = 0

        def snapshot():
            nonlocal active, maximum
            with lock:
                active += 1
                maximum = max(maximum, active)
            time.sleep(0.1)
            with lock:
                active -= 1
            return {'process_cpu_seconds_total': 1.0,
                    'process_resident_memory_bytes': 1024,
                    'voice_platform_attachment_filesystem_available_bytes': 1 << 30}

        def read(resources):
            start.wait(timeout=3)
            return resources.read()

        with patch('tools.load.guard.resources.owned', return_value=stack.api), \
                patch('tools.load.guard.resources.output', return_value='2000000000'), \
                patch('tools.load.guard.resources.snapshot', side_effect=snapshot):
            resources = Resources(stack)
            with ThreadPoolExecutor(max_workers=2) as pool:
                results = list(pool.map(read, [resources, resources]))
        self.assertEqual(maximum, 1)
        self.assertEqual([sample['CPUPercent'] for sample in results], [0, 0])


if __name__ == '__main__':
    unittest.main()
