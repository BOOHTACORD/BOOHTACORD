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

    def test_installer_cannot_cancel_another_writer(self):
        broken = copy.deepcopy(self.workflows)
        broken['deploy-production.yaml']['concurrency']['cancel-in-progress'] = 'true'
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
