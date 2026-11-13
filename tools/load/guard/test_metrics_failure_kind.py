import socket
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from urllib.error import HTTPError, URLError

from .resources import Resources
from .sample_failure import SampleFailure


class MetricsFailureKindTests(unittest.TestCase):
    def test_private_metrics_failure_exposes_only_fixed_stage(self):
        cases = [
            (socket.timeout('private'), 'resource_metrics_timeout'),
            (URLError(socket.timeout('private')), 'resource_metrics_timeout'),
            (URLError(ConnectionRefusedError('private')), 'resource_metrics_unavailable'),
            (HTTPError('http://private', 503, 'private', {}, None), 'resource_metrics_http'),
            (ValueError('private'), 'resource_metrics_invalid'),
        ]
        stack = SimpleNamespace(api='owned-api')
        for cause, expected in cases:
            with self.subTest(expected=expected), \
                 patch('tools.load.guard.resources.owned', return_value=stack.api), \
                 patch('tools.load.guard.resources.output', return_value='2000000000'), \
                 patch('tools.load.guard.resources.snapshot', side_effect=cause):
                with self.assertRaises(SampleFailure) as failure:
                    Resources(stack).read()
                self.assertEqual(str(failure.exception), expected)
