import copy
import unittest
from pathlib import Path
import yaml
from tools.verify.action_pins.policy import normalized
from tools.verify.workflows.delivery import check


class DeliveryWorkflowTests(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[3]
        self.workflows = {path.name: yaml.load(normalized(path.read_text(encoding='utf-8')), Loader=yaml.BaseLoader)
                          for path in (root / '.github/workflows').glob('*.yaml')}

    def test_current_delivery_graph(self):
        check(self.workflows)

    def test_route_proof_retention_is_exact_and_cannot_be_skipped_or_read_other_paths(self):
        for mutation in ('name','path','missing','retention','skip','credential','extra'):
            broken=copy.deepcopy(self.workflows)
            steps=broken['deploy-production.yaml']['jobs']['route']['steps'];upload=steps[4]
            if mutation=='name':upload['with']['name']='unbound-proof'
            if mutation=='path':upload['with']['path']='.env'
            if mutation=='missing':upload['with']['if-no-files-found']='ignore'
            if mutation=='retention':upload['with']['retention-days']='1'
            if mutation=='skip':upload['if']='false'
            if mutation=='credential':upload['env']={'KEY':'${{ secrets.DEPLOY_SSH_PRIVATE_KEY }}'}
            if mutation=='extra':steps.append({'run':'echo unexpected'})
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):check(broken)

    def test_installer_cannot_cancel_another_writer(self):
        broken = copy.deepcopy(self.workflows)
        broken['deploy-production.yaml']['jobs']['install']['concurrency']['cancel-in-progress'] = 'true'
        with self.assertRaises(ValueError): check(broken)

    def test_builder_requires_all_source_bound_gates(self):
        broken = copy.deepcopy(self.workflows)
        broken['build-server.yaml']['jobs']['bundle']['needs'] = ['backend', 'web']
        with self.assertRaises(ValueError): check(broken)

    def test_untrusted_workflow_completion_cannot_deploy(self):
        broken = copy.deepcopy(self.workflows)
        broken['deploy-production.yaml']['jobs']['install']['if'] = 'true'
        with self.assertRaises(ValueError): check(broken)

    def test_server_routing_never_uses_a_separate_path_filter(self):
        broken = copy.deepcopy(self.workflows)
        broken['build-server.yaml']['on']['push']['paths'] = ['backend/**']
        with self.assertRaises(ValueError): check(broken)

    def test_expected_no_release_route_does_not_gain_production_credentials(self):
        for update in [{'environment': 'production'}, {'permissions': {'contents': 'write'}},
                       {'env': {'DEPLOY_SSH_PRIVATE_KEY': '${{ secrets.DEPLOY_SSH_PRIVATE_KEY }}'}}]:
            broken = copy.deepcopy(self.workflows)
            broken['deploy-production.yaml']['jobs']['route'].update(update)
            with self.subTest(update=update), self.assertRaises(ValueError):
                check(broken)

    def test_installer_cannot_ignore_producer_route(self):
        broken = copy.deepcopy(self.workflows)
        broken['deploy-production.yaml']['jobs']['install']['needs'] = []
        with self.assertRaises(ValueError): check(broken)

    def test_receipt_and_route_job_display_names_cannot_drift_from_the_decoder(self):
        for workflow, job in [('build-server.yaml', 'web'), ('ci-frontend.yaml', 'frontend'),
                              ('build-server.yaml', 'bundle'), ('build-server.yaml', 'changes')]:
            broken = copy.deepcopy(self.workflows)
            broken[workflow]['jobs'][job]['name'] = 'renamed-identity'
            with self.subTest(workflow=workflow, job=job), self.assertRaises(ValueError): check(broken)

    def test_route_sdk_bootstrap_is_an_exact_read_only_allowlist(self):
        for mutation in ('extra', 'loose', 'skip', 'credential'):
            broken=copy.deepcopy(self.workflows)
            steps=broken['deploy-production.yaml']['jobs']['route']['steps']
            if mutation=='extra': steps.insert(1,{'run':'echo unexpected'})
            if mutation=='loose': steps[1]['with']['python-version']='3.12'
            if mutation=='skip': steps[2]['if']='false'
            if mutation=='credential': steps[1]['env']={'KEY':'${{ secrets.DEPLOY_SSH_PRIVATE_KEY }}'}
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): check(broken)
