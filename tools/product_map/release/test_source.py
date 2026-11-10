import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.product_map.release.source import require_exact_source


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.git('init', '-q')
        folder = self.root / 'product-map/features/voice'
        folder.mkdir(parents=True)
        (folder / 'core.yaml').write_text('{}', encoding='utf-8')
        self.git('add', 'product-map/features/voice/core.yaml')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                 'commit', '-qm', 'fixture')
        self.sha = self.git('rev-parse', 'HEAD').strip()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.root), *args], text=True)

    def test_accepts_only_clean_exact_source(self):
        require_exact_source(self.root, self.sha)
        with self.assertRaisesRegex(ValueError, 'source'):
            require_exact_source(self.root, 'b' * 40)
        (self.root / 'product-map/features/voice/core.yaml').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'dirty'):
            require_exact_source(self.root, self.sha)

    def test_rejects_untracked_even_if_gitignored(self):
        self.git('config', 'core.excludesFile', str(self.root / 'exclude'))
        (self.root / 'exclude').write_text('*.yaml\n', encoding='utf-8')
        (self.root / 'product-map/features/voice/hidden.yaml').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'untracked'):
            require_exact_source(self.root, self.sha)
