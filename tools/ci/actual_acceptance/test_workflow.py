"""Automatic actual gates are mandatory, isolated and cannot publish a QA release."""
from pathlib import Path
import unittest
import yaml
from .catalog import OPERATIONS,REPORTS

ROOT=Path(__file__).resolve().parents[3]


def workflow(name):return yaml.load((ROOT/'.github/workflows'/name).read_text(),Loader=yaml.BaseLoader)


class WorkflowTests(unittest.TestCase):
    def test_original_controllers_are_reused_in_disposable_vms_with_strict_fan_in(self):
        doc=workflow('ci-actual-acceptance.yaml');runtime=doc['jobs']['runtime'];fan=doc['jobs']['actual-acceptance']
        self.assertEqual(['self-hosted','linux','x64','boohtacord-ci-ephemeral'],runtime['runs-on']);self.assertEqual('false',runtime['strategy']['fail-fast'])
        self.assertEqual('always()',fan['if']);self.assertEqual('runtime',fan['needs'])
        self.assertTrue(any('actual_acceptance.fan_in' in s.get('run','') for s in fan['steps']))
        for profile,commands in OPERATIONS.items():
            self.assertTrue(REPORTS[profile]);self.assertTrue(any('tools.qa.' in ' '.join(command) for command in commands))
        self.assertEqual({'contents':'read'},doc['permissions'])

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
