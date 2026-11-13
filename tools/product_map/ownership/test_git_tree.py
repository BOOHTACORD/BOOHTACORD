import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.product_map.ownership.git_tree import tracked_files
from tools.product_map.ownership.run import run


def git(root, *args):
    return subprocess.run(['git', *args], cwd=root, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


class GitTreeTests(unittest.TestCase):
    def test_committed_tree_is_read_not_uncommitted_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            git(root, 'init')
            folder = root / 'backend/internal/voice'
            folder.mkdir(parents=True)
            (folder / 'old.go').write_text('package voice', encoding='utf-8')
            git(root, 'add', 'backend/internal/voice/old.go')
            git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                '-c', 'commit.gpgsign=false', 'commit', '-m', 'base')
            sha = git(root, 'rev-parse', 'HEAD').decode().strip()
            (folder / 'new.go').write_text('package voice', encoding='utf-8')
            self.assertEqual(tracked_files(root, sha), ['backend/internal/voice/old.go'])
            for invalid in ('HEAD', '--help', 'a' * 39):
                with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                    tracked_files(root, invalid)
            with self.assertRaises(subprocess.CalledProcessError):
                tracked_files(root, 'a' * 40)

    @patch('tools.product_map.ownership.run.validate')
    @patch('tools.product_map.ownership.run.load_curated_catalog')
    def test_gate_rejects_a_committed_new_unmapped_source(self, catalog, _validate):
        catalog.return_value = {'components': [], 'features': []}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            git(root, 'init')
            registry = root / 'tools/qa/local_features/features.json'
            registry.parent.mkdir(parents=True)
            registry.write_text('{}', encoding='utf-8')
            git(root, 'add', 'tools/qa/local_features/features.json')
            git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                '-c', 'commit.gpgsign=false', 'commit', '-m', 'base')
            base = git(root, 'rev-parse', 'HEAD').decode().strip()
            source = root / 'backend/internal/voice/new.go'
            source.parent.mkdir(parents=True)
            source.write_text('package voice', encoding='utf-8')
            git(root, 'add', 'backend/internal/voice/new.go')
            git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                '-c', 'commit.gpgsign=false', 'commit', '-m', 'new')
            self.assertEqual(run(root, base), ['backend/internal/voice/new.go'])
