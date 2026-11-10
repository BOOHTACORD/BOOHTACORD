import subprocess
import tempfile
import unittest
from pathlib import Path

from .historical_artifact import content_at_revision, evidence_content


class HistoricalArtifactTest(unittest.TestCase):
    def test_reads_exact_revision_without_rewriting_historical_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            path = root / 'backlog/tasks.yaml'
            path.parent.mkdir()
            path.write_text('historical\n', encoding='utf8')
            config = root / 'deploy/livekit/livekit.yaml'
            config.parent.mkdir(parents=True)
            config.write_bytes(b'historical livekit configuration\n')
            subprocess.run(['git', '-C', str(root), 'add', 'backlog/tasks.yaml', 'deploy/livekit/livekit.yaml'], check=True)
            subprocess.run(['git', '-C', str(root), '-c', 'user.name=Fixture', '-c',
                            'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], check=True)
            revision = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
            path.write_text('current\n', encoding='utf8')
            config.write_bytes(b'current livekit configuration\n')
            self.assertEqual(evidence_content(root, revision, 'deploy/livekit/livekit.yaml'), b'current livekit configuration\n')
            self.assertEqual(content_at_revision(root, revision, 'backlog/tasks.yaml'), b'historical\n')
            self.assertEqual(evidence_content(root, revision, 'backlog/tasks.yaml'), b'historical\n')
            other = root / 'deploy/livekit.yaml'
            other.parent.mkdir(exist_ok=True)
            other.write_bytes(b'current configuration\n')
            self.assertEqual(evidence_content(root, revision, 'deploy/livekit.yaml'), b'current configuration\n')
            with self.assertRaises(RuntimeError):
                content_at_revision(root, '0' * 40, 'backlog/tasks.yaml')
            for invalid in ('../secret', '/absolute', 'backlog/../../secret', 'a:b'):
                with self.assertRaises(ValueError):
                    content_at_revision(root, revision, invalid)


if __name__ == '__main__':
    unittest.main()
