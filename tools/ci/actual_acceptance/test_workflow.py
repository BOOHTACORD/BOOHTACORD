"""Automatic actual gates are mandatory, isolated and cannot publish a QA release."""
from pathlib import Path
import unittest
import yaml
from .catalog import OPERATIONS,REPORTS
from tools.ci.runner_pool.routing import GITHUB_LINUX

ROOT=Path(__file__).resolve().parents[3]


def workflow(name):return yaml.load((ROOT/'.github/workflows'/name).read_text(),Loader=yaml.BaseLoader)


class WorkflowTests(unittest.TestCase):
    def test_original_controllers_are_reused_in_disposable_vms_with_strict_fan_in(self):
        doc=workflow('ci-actual-acceptance.yaml');runtime=doc['jobs']['runtime'];fan=doc['jobs']['actual-acceptance']
        self.assertEqual(GITHUB_LINUX,runtime['runs-on']);self.assertEqual('false',runtime['strategy']['fail-fast'])
        self.assertEqual('always()',fan['if']);self.assertEqual('runtime',fan['needs'])
        self.assertTrue(any('actual_acceptance.fan_in' in s.get('run','') for s in fan['steps']))
        for profile,commands in OPERATIONS.items():
            self.assertTrue(REPORTS[profile]);self.assertTrue(any('tools.qa.' in ' '.join(command) for command in commands))
        visibility=next(command for command in OPERATIONS['next'] if 'visibility_smoke.mjs' in ' '.join(command))
        visibility=' '.join(visibility)
        self.assertLess(visibility.index('window_manager'),visibility.index('visibility_smoke.mjs'))
        install=next(s for s in runtime['steps'] if s.get('name')=='Install window manager for real visibility transitions')
        self.assertIn('openbox x11-utils',install['run'])
        self.assertEqual({'contents':'read'},doc['permissions'])

    def test_next_keeps_runner_regressions_and_window_manager_readiness(self):
        node = next(command for command in OPERATIONS['next'] if command[:2] == ['node', '--test'])
        for name in ('fresh_browser', 'mutation_session', 'revocation_sql'):
            self.assertIn('tools/qa/next_client_acceptance/'+name+'.test.mjs', node)
        self.assertTrue(any('tools.qa.next_client_acceptance.test_window_manager' in command
                            for command in OPERATIONS['next']))

    def test_no_duplicate_pr_trigger_or_feature_push_can_publish(self):
        for name in ('client-lifecycle-acceptance','next-client-acceptance','sfu-snapshot-measure'):
            self.assertEqual({'workflow_dispatch'},set(workflow(name+'.yaml')['on']))
        for name,job in [('desktop-updater-acceptance','macos-beta-package'),('windows-updater-acceptance','installed-update')]:
            doc=workflow(name+'.yaml');self.assertEqual({'workflow_dispatch'},set(doc['on']))
            self.assertEqual('false',doc['on']['workflow_dispatch']['inputs']['publish_qa']['default'])
            self.assertIn('inputs.publish_qa',doc['jobs'][job]['if']);self.assertIn("refs/heads/master",doc['jobs'][job]['if'])

    def test_rollback_does_not_run_frozen_historical_commit_or_run_ids(self):
        doc=workflow('qa-compatible-rollback.yaml');text=str(doc)
        self.assertEqual({'workflow_dispatch'},set(doc['on']))
        self.assertNotIn('4261f720',text);self.assertNotIn('39171728724',text)
        self.assertIn('tools.ci.actual_acceptance.manual_inputs',text)
