"""Unsafe local SFU probe inputs must fail before a process starts."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from .livekit import main


class RunnerBoundaryTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.server = self.root / 'server'
        self.server.write_bytes(b'inert fixture')
        self.client = self.root / 'client.exe'
        self.client.write_bytes(b'inert fixture')
        self.digest = hashlib.sha256(self.server.read_bytes()).hexdigest()

    def args(self, digest):
        return ['probe', '--server', str(self.server), '--server-sha256', digest,
                '--client', str(self.client), '--web', str(self.root), '--result', str(self.root / 'result.json')]

    def test_result_outside_research_root_is_rejected(self):
        with patch('sys.argv', self.args(self.digest)), patch('subprocess.Popen') as spawn:
            with self.assertRaisesRegex(ValueError, 'research'): main()
            spawn.assert_not_called()

    def test_hash_and_marker_fail_before_any_process(self):
        for digest, marker in [('0' * 64, True), (self.digest, False)]:
            with self.subTest(marker=marker), patch('sys.argv', self.args(digest)), \
                 patch('tools.audio.windows_v02_probe.livekit.check_output'), patch('subprocess.Popen') as spawn:
                marker_path = self.root / 'rnnoise-v02-research-only.txt'
                if marker: marker_path.touch()
                else: marker_path.unlink(missing_ok=True)
                expected = 'checksum' if marker else 'marker'
                with self.assertRaisesRegex(ValueError, expected): main()
                spawn.assert_not_called()


if __name__ == '__main__':
    unittest.main()
