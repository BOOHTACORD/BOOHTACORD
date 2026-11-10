import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.product_map.catalog.history import read_previous_catalog
from tools.product_map.catalog.transition import validate_transition


def git(root, *args):
    return subprocess.run(['git', *args], cwd=root, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        git(self.root, 'init')
        path = self.root / 'product-map/features/voice/core.yaml'
        path.parent.mkdir(parents=True)
        self.path = path
        self.data = {'components': [{'id': 'cmp.voice'}], 'features': [
            {'id': 'voice.a', 'target_revision': 1,
             'behavior_revisions': [{'revision': 1, 'summary': 'one'}]}]}
        path.write_text(json.dumps(self.data), encoding='utf-8')
        git(self.root, 'add', 'product-map/features/voice/core.yaml')
        git(self.root, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
            '-c', 'commit.gpgsign=false', 'commit', '-m', 'base')
        self.sha = git(self.root, 'rev-parse', 'HEAD').decode().strip()

    def test_reads_committed_baseline_not_worktree_and_blocks_removal(self):
        self.path.write_text('{"components": [], "features": []}', encoding='utf-8')
        old = read_previous_catalog(self.root, self.sha)
        self.assertEqual(old, self.data)
        with self.assertRaisesRegex(ValueError, 'removed'):
            validate_transition(old, {'features': [], 'components': []})

    def test_rejects_revision_rewrite_and_invalid_base(self):
        old = read_previous_catalog(self.root, self.sha)
        modified = json.loads(json.dumps(self.data))
        modified['features'][0]['behavior_revisions'][0]['summary'] = 'changed'
        with self.assertRaisesRegex(ValueError, 'historical'):
            validate_transition(old, modified)
        for base in ('HEAD', '--help', 'a' * 39):
            with self.subTest(base=base), self.assertRaises(ValueError):
                read_previous_catalog(self.root, base)

    def test_missing_commit_is_not_an_empty_baseline(self):
        with self.assertRaises(subprocess.CalledProcessError):
            read_previous_catalog(self.root, 'b' * 40)
