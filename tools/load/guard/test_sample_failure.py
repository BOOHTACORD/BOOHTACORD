import subprocess
import unittest
from types import SimpleNamespace
from unittest.mock import Mock

from .sample_failure import SampleFailure, checked_inputs


class SampleFailureTests(unittest.TestCase):
    def test_fixture_and_resource_failures_are_fixed_categories(self):
        resources = SimpleNamespace(read=Mock(return_value={}))
        manifest = {'Nonce': 'synthetic', 'Accounts': []}
        for exc in [ValueError('private'), subprocess.TimeoutExpired('private', 1)]:
            with self.assertRaises(SampleFailure) as failure:
                checked_inputs(None, manifest, resources, Mock(side_effect=exc))
            self.assertEqual(str(failure.exception), 'fixture_verification')
        resources.read.side_effect = OSError('private')
        with self.assertRaises(SampleFailure) as failure:
            checked_inputs(None, manifest, resources, Mock())
        self.assertEqual(str(failure.exception), 'resource_snapshot')
