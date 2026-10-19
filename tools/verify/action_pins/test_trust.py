import copy
from pathlib import Path
import unittest
import yaml
from .policy import ROOT, normalized
from .trust import check


class TrustBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.workflows = {p.name: yaml.load(normalized(p.read_text()), Loader=yaml.BaseLoader)
                          for p in (ROOT / '.github/workflows').glob('*.yaml')}

    def test_current_trust_matrix(self):
        check(self.workflows)

    def test_untrusted_pr_cannot_get_write_self_hosted_or_signing_credentials(self):
        updates = [{'permissions': {'contents': 'write'}}, {'runs-on': ['self-hosted', 'linux']},
                   {'env': {'KEY': '${{ secrets.RELEASE_SIGNING_PRIVATE_KEY }}'}}]
        for update in updates:
            broken = copy.deepcopy(self.workflows)
            broken['ci-actual-acceptance.yaml']['jobs']['runtime'].update(update)
            with self.subTest(update=update), self.assertRaises(ValueError):
                check(broken)

    def test_pull_request_target_and_secret_inheritance_are_rejected(self):
        broken = copy.deepcopy(self.workflows)
        broken['ci.yaml']['on']['pull_request_target'] = {}
        with self.assertRaises(ValueError): check(broken)
        broken = copy.deepcopy(self.workflows)
        broken['ci.yaml']['jobs']['backend']['secrets'] = 'inherit'
        with self.assertRaises(ValueError): check(broken)

    def test_guard_substring_is_not_a_trust_boundary(self):
        broken = copy.deepcopy(self.workflows)
        broken['build-server.yaml']['jobs']['bundle']['if'] += ' || true'
        with self.assertRaises(ValueError): check(broken)

    def test_release_and_persistent_runner_require_protected_trusted_source(self):
        for workflow, job in [('android-release.yaml', 'android-release'), ('webrtc-macos-sdk.yaml', 'publish')]:
            for update in [{'if': 'true'}, {'environment': None}]:
                broken = copy.deepcopy(self.workflows)
                broken[workflow]['jobs'][job].update(update)
                with self.subTest(workflow=workflow, update=update), self.assertRaises(ValueError):
                    check(broken)

    def test_read_only_checkouts_cannot_keep_credentials(self):
        broken = copy.deepcopy(self.workflows)
        step = broken['ci-contracts.yaml']['jobs']['contracts']['steps'][0]
        step['with'] = {'persist-credentials': 'true'}
        with self.assertRaises(ValueError): check(broken)

    def test_indirect_secret_access_and_workflow_env_are_not_a_bypass(self):
        for expression in ["${{ secrets['SIGNING_KEY'] }}", '${{ toJSON(secrets) }}']:
            broken = copy.deepcopy(self.workflows)
            broken['ci-actual-acceptance.yaml']['jobs']['runtime']['env'] = {'KEY': expression}
            with self.subTest(expression=expression), self.assertRaises(ValueError): check(broken)
        broken = copy.deepcopy(self.workflows)
        broken['ci.yaml']['env'] = {'KEY': '${{ secrets.SIGNING_KEY }}'}
        with self.assertRaises(ValueError): check(broken)

    def test_runner_groups_expressions_and_unknown_labels_are_not_hosted(self):
        for runner in [{'group': 'production'}, '${{ inputs.runner }}', 'privileged-runner']:
            broken = copy.deepcopy(self.workflows)
            broken['ci-actual-acceptance.yaml']['jobs']['runtime']['runs-on'] = runner
            with self.subTest(runner=runner), self.assertRaises(ValueError): check(broken)

    def test_dependency_install_precedes_yaml_policy_imports(self):
        steps = self.workflows['ci-contracts.yaml']['jobs']['contracts']['steps']
        installed = next(i for i, step in enumerate(steps) if 'pip install' in step.get('run', ''))
        verifier = next(i for i, step in enumerate(steps) if 'tools.verify.action_pins' in step.get('run', ''))
        self.assertLess(installed, verifier)

    def test_publisher_scopes_cannot_expand_or_drop_existing_required_access(self):
        for permissions in [{'contents': 'read'}, {'contents': 'write', 'id-token': 'write'},
                            {'contents': 'write', 'actions': 'write'}]:
            broken = copy.deepcopy(self.workflows)
            broken['android-release.yaml']['jobs']['android-release']['permissions'] = permissions
            with self.subTest(permissions=permissions), self.assertRaises(ValueError): check(broken)

    def test_child_gate_failures_cannot_be_hidden_by_job_or_step_soft_failure(self):
        for location in ('job', 'step'):
            broken = copy.deepcopy(self.workflows)
            job = broken['ci-backend.yaml']['jobs']['backend']
            target = job if location == 'job' else next(
                step for step in job['steps'] if step.get('run') == 'python3 -m tools.ci.receipts.run backend --parts .out/ci/backend-parts')
            target['continue-on-error'] = 'true'
            with self.subTest(location=location), self.assertRaises(ValueError): check(broken)
