import io
import unittest
from unittest.mock import patch

from .metrics import snapshot


class ResourceMetricsViewTests(unittest.TestCase):
    def test_resource_scrape_uses_bounded_subset_of_existing_endpoint(self):
        response = io.BytesIO(b'process_cpu_seconds_total 3\n')
        with patch('tools.load.guard.metrics.urllib.request.urlopen', return_value=response) as open_url:
            self.assertEqual(snapshot(resource_only=True), {'process_cpu_seconds_total': 3.0})
        open_url.assert_called_once_with('http://127.0.0.1:4820/metrics?view=resources', timeout=2)


if __name__ == '__main__':
    unittest.main()
