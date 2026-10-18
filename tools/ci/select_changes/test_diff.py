import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from .run import changed_paths, main


class DiffTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        environment = patch.dict(os.environ)
        environment.start()
        self.addCleanup(environment.stop)
        os.environ.pop('GITHUB_SHA', None)
        self.old = os.getcwd()
        os.chdir(self.tmp.name)
        self.addCleanup(os.chdir, self.old)
        self.git('init', '-q')
        self.git('config', 'user.email', 'ci-fixture@example.invalid')
        self.git('config', 'user.name', 'CI fixture')
        Path('docs').mkdir()
        Path('docs/a').write_text('one')
        self.git('add', 'docs/a')
        self.git('commit', '-qm', 'base')
        self.base = self.git('rev-parse', 'HEAD')

    def git(self, *args):
        return subprocess.check_output(['git', *args], text=True, stderr=subprocess.DEVNULL).strip()

    def test_rename_and_delete_keep_both_ownership_paths(self):
        Path('clients').mkdir()
        self.git('mv', 'docs/a', 'clients/a')
        self.git('commit', '-qm', 'move')
        self.assertEqual(set(changed_paths({'before': self.base}, 'push')), {'docs/a', 'clients/a'})

    def test_force_push_uses_exact_before_not_merge_base(self):
        Path('docs/a').write_text('two')
        self.git('commit', '-qam', 'old branch')
        before = self.git('rev-parse', 'HEAD')
        self.git('checkout', '-q', '--detach', self.base)
        Path('backend').mkdir()
        Path('backend/a').write_text('new')
        self.git('add', 'backend/a')
        self.git('commit', '-qm', 'replacement')
        self.assertEqual(set(changed_paths({'before': before}, 'push')), {'backend/a', 'docs/a'})

    def test_pr_base_and_merge_checkout_do_not_include_unrelated_history(self):
        Path('docs/a').write_text('two')
        self.git('commit', '-qam', 'feature')
        event = {'pull_request': {'base': {'sha': self.base}}}
        self.assertEqual(changed_paths(event, 'pull_request'), ['docs/a'])
        self.assertEqual(changed_paths({'before': self.git('rev-parse', 'HEAD')}, 'push'), [])

    def test_missing_base_first_push_tag_manual_and_wrong_checkout_are_uncertain(self):
        for event, name in [({}, 'pull_request'), ({'before': '0' * 40}, 'push'),
                            ({'before': 'f' * 40}, 'push'), ({'before': '$(touch bad)'}, 'push'),
                            ({'before': self.base, 'ref': 'refs/tags/v1'}, 'push'), ({}, 'workflow_dispatch')]:
            self.assertIsNone(changed_paths(event, name))
        self.assertFalse(Path('bad').exists())
        with patch.dict(os.environ, {'GITHUB_SHA': 'f' * 40}):
            self.assertIsNone(changed_paths({'before': self.base}, 'push'))

    def test_malformed_event_emits_all_gates_without_printing_payload(self):
        Path('event.json').write_text('{invalid')
        with patch.dict(os.environ, {'GITHUB_EVENT_PATH': 'event.json', 'GITHUB_EVENT_NAME': 'push',
                                     'GITHUB_OUTPUT': 'outputs'}):
            main()
        output = Path('outputs').read_text()
        self.assertIn('server_release_impact=true', output)
        self.assertIn('native_release_impact=true', output)
        self.assertIn('contracts=true', output)

    def test_real_merge_checkout_uses_pr_base_and_retains_all_feature_commits(self):
        self.git('checkout', '-qb', 'feature')
        Path('docs/a').write_text('feature one')
        self.git('commit', '-qam', 'feature one')
        Path('docs/b').write_text('feature two')
        self.git('add', 'docs/b')
        self.git('commit', '-qm', 'feature two')
        self.git('checkout', '-q', '--detach', self.base)
        Path('docs/main-only').write_text('main')
        self.git('add', 'docs/main-only')
        self.git('commit', '-qm', 'main advanced')
        base = self.git('rev-parse', 'HEAD')
        self.git('merge', '--no-ff', '-qm', 'tested merge', 'feature')
        with patch.dict(os.environ, {'GITHUB_SHA': self.git('rev-parse', 'HEAD')}):
            self.assertEqual(set(changed_paths({'pull_request': {'base': {'sha': base}}}, 'pull_request')),
                             {'docs/a', 'docs/b'})
