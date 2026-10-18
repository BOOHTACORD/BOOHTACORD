import hashlib
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch
from .identity import api_binary_sha256


class BinaryIdentityTests(unittest.TestCase):
    def stack(self, work):
        return SimpleNamespace(work=Path(work), owner='qa-owned', api='qa-owned-api',
                               resources=[('container', 'qa-owned-api')])

    def test_hashes_only_the_actual_owned_container_executable_and_removes_copy(self):
        with tempfile.TemporaryDirectory() as work:
            stack = self.stack(work)
            def copy(*args, **options):
                self.assertEqual(args[:3], ('docker', 'cp', 'qa-owned-api:/api'))
                Path(args[3]).write_bytes(b'synthetic executable')
            with patch('tools.qa.sfu_snapshot_measure.identity.output', return_value=stack.owner), \
                 patch('tools.qa.sfu_snapshot_measure.identity.run', side_effect=copy):
                self.assertEqual(api_binary_sha256(stack), hashlib.sha256(b'synthetic executable').hexdigest())
            self.assertEqual(list(Path(work).iterdir()), [])

    def test_foreign_container_is_not_copied_or_attested(self):
        with tempfile.TemporaryDirectory() as work:
            with patch('tools.qa.sfu_snapshot_measure.identity.output', return_value='foreign'), \
                 patch('tools.qa.sfu_snapshot_measure.identity.run') as copy:
                with self.assertRaises(ValueError): api_binary_sha256(self.stack(work))
                copy.assert_not_called()

    def test_unregistered_container_is_rejected_before_docker_access(self):
        with tempfile.TemporaryDirectory() as work:
            stack = self.stack(work);stack.resources = []
            with patch('tools.qa.sfu_snapshot_measure.identity.output') as inspect:
                with self.assertRaises(ValueError): api_binary_sha256(stack)
                inspect.assert_not_called()
