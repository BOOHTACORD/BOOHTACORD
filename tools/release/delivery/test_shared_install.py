"""Automatic and retained callers share every credential-bearing delivery stage."""
import copy
from pathlib import Path
import unittest
import yaml
from tools.verify.action_pins.policy import normalized
from tools.verify.workflows.shared_install import check


class SharedInstallPolicyTests(unittest.TestCase):
    def setUp(self):
        root=Path(__file__).resolve().parents[3]
        self.workflows={p.name:yaml.load(normalized(p.read_text()),Loader=yaml.BaseLoader) for p in (root/'.github/workflows').glob('*.yaml')}
        self.action=yaml.load(normalized((root/'.github/actions/install-trusted-server/action.yaml').read_text()),Loader=yaml.BaseLoader)

    def test_current_shared_path_is_protected_and_exactly_bound(self): check(self.workflows,self.action)

    def test_no_historical_controller_checkout_or_hidden_alternative_path(self):
        for mutation in ('historical','extra','mode','source','run'):
            workflows=copy.deepcopy(self.workflows); job=workflows['deploy-production.yaml']['jobs']['install']
            if mutation=='historical': job['steps'][0]['with']['ref']='${{ github.event.workflow_run.head_sha }}'
            elif mutation=='extra': job['steps'].append({'run':'echo unexpected'})
            else:
                key={'mode':'mode','source':'revision','run':'build-run-id'}[mutation]
                job['steps'][-1]['with'][key]='unbound'
            with self.subTest(mutation=mutation),self.assertRaises(ValueError): check(workflows,self.action)

    def test_no_credentials_before_revalidation_no_ignored_failures_or_missing_receipts(self):
        for mutation in ('order','key','skip','ignore','retention','upload','download'):
            action=copy.deepcopy(self.action); steps=action['runs']['steps']
            if mutation=='order': steps[3],steps[4]=steps[4],steps[3]
            elif mutation=='key': steps[1].setdefault('env',{})['DEPLOY_SSH_PRIVATE_KEY']='${{ inputs.ssh-private-key }}'
            elif mutation=='skip': steps[3]['if']='false'
            elif mutation=='ignore': steps[5]['continue-on-error']='true'
            elif mutation=='retention': steps[-1]['with']['retention-days']='7'
            elif mutation=='upload': steps[-1]['if']='success()'
            else: steps[2]['run']='echo downloaded'
            with self.subTest(mutation=mutation),self.assertRaises(ValueError): check(self.workflows,action)
