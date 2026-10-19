"""Only one master server producer; native gates never gain release authority."""
import copy
from pathlib import Path
import unittest
import yaml
from tools.verify.action_pins.policy import normalized
from . import workflow


class MasterWorkflowTests(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[3]
        self.workflows = {p.name: yaml.load(normalized(p.read_text()), Loader=yaml.BaseLoader)
                          for p in (root / '.github/workflows').glob('*.yaml')}

    def test_actual_graph_has_one_server_producer_and_independent_native_quality(self):
        workflow.validate(self.workflows)

    def test_pr_ci_cannot_duplicate_master_gates_or_skip_pr_contracts(self):
        for mutation in ('push', 'manual-master', 'skip-pr'):
            value = copy.deepcopy(self.workflows)
            if mutation == 'push': value['ci.yaml']['on']['push'] = {'branches': ['master']}
            if mutation == 'manual-master': value['ci.yaml']['jobs']['changes'].pop('if')
            if mutation == 'skip-pr': value['ci.yaml']['jobs']['contracts']['if'] = 'false'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): workflow.validate(value)

    def test_native_master_cannot_add_server_dependencies_or_production_credentials(self):
        for mutation in ('contracts', 'needs', 'environment', 'skip', 'upload'):
            value = copy.deepcopy(self.workflows); native = value['native-master.yaml']; job = native['jobs']['native-required']
            if mutation == 'contracts': native['jobs']['contracts'] = {'uses': './.github/workflows/ci-contracts.yaml'}
            if mutation == 'needs': job['needs'].append('contracts')
            if mutation == 'environment': job['environment'] = 'production'
            if mutation == 'skip': job['if'] = 'success()'
            if mutation == 'upload': job['steps'][-1]['with']['if-no-files-found'] = 'ignore'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): workflow.validate(value)

    def test_server_quality_is_mandatory_exact_source_and_cannot_skip_contracts(self):
        for mutation in ('contracts', 'quality', 'builder', 'source', 'artifact', 'optional'):
            value = copy.deepcopy(self.workflows); build = value['build-server.yaml']; job = build['jobs']['server-quality']
            if mutation == 'contracts': build['jobs']['contracts']['if'] = "needs.changes.outputs.server_release_impact == 'true'"
            if mutation == 'quality': job['if'] = 'success()'
            if mutation == 'builder': build['jobs']['bundle']['needs'].remove('server-quality')
            if mutation == 'source': job['steps'][-2]['env']['MASTER_NEEDS'] = '{}'
            if mutation == 'artifact': job['steps'][-1]['with']['name'] = 'quality-master-server-latest'
            if mutation == 'optional': job['steps'][-2]['continue-on-error'] = 'true'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): workflow.validate(value)

    def test_retry_must_download_current_attempt_receipts_and_selected_producer_bundle(self):
        for mutation in ('receipts', 'bundle', 'download', 'retained', 'smoke'):
            value = copy.deepcopy(self.workflows); build = value['build-server.yaml']['jobs']['bundle']
            if mutation == 'receipts': build['steps'][1]['with']['pattern'] = 'check-*-${{ github.sha }}'
            if mutation == 'bundle': build['steps'][-1]['with']['name'] = 'server-${{ github.sha }}'
            if mutation == 'smoke':
                for step in value['ci-backend.yaml']['jobs']['backend']['steps']:
                    if step.get('with', {}).get('name', '').startswith('backend-load-smoke-'):
                        step['with']['name'] = 'backend-load-smoke-${{ github.sha }}'
            if mutation in ('download', 'retained'):
                name = 'deploy-production.yaml' if mutation == 'download' else 'install-retained-release.yaml'
                for step in value[name]['jobs']['install']['steps']:
                    if step.get('uses') == 'actions/download-artifact@v4': step['with']['name'] = 'server-${{ steps.producer.outputs.revision }}'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): workflow.validate(value)

    def test_every_server_upload_is_attempt_bound_including_load_smoke(self):
        for name in ('build-server.yaml', 'ci-backend.yaml', 'ci-frontend.yaml', 'ci-contracts.yaml'):
            for job in self.workflows[name]['jobs'].values():
                for step in job.get('steps', []):
                    if step.get('uses') == 'actions/upload-artifact@v4':
                        artifact = step['with']['name']
                        for field in ('sha', 'run_id', 'run_attempt'):
                            self.assertIn('${{ github.' + field + ' }}', artifact)

    def test_builder_downloads_three_exact_receipt_names_without_wildcard_merge(self):
        steps = self.workflows['build-server.yaml']['jobs']['bundle']['steps']
        downloads = [s for s in steps if s.get('uses') == 'actions/download-artifact@v4']
        execution = '${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'
        self.assertEqual([{'name': 'check-' + gate + '-' + execution, 'path': '.out/checks'}
                          for gate in ('backend', 'web', 'contracts')], [s['with'] for s in downloads])
        self.assertTrue(all(not s.get('if') for s in downloads))
