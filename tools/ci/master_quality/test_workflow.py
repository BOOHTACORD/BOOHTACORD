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

    def test_metadata_push_cannot_cancel_another_source_master_quality(self):
        # A runtime commit can still be building when the next push only changes
        # evidence and skips all native/bundle work. It must keep its own slot.
        groups = []
        for name in ('build-server.yaml', 'native-master.yaml'):
            concurrency = self.workflows[name]['concurrency']
            group = concurrency['group']
            runtime = group.replace('${{ github.ref }}', 'refs/heads/master').replace('${{ github.sha }}', 'a' * 40)
            metadata = group.replace('${{ github.ref }}', 'refs/heads/master').replace('${{ github.sha }}', 'b' * 40)
            with self.subTest(workflow=name):
                self.assertNotEqual(runtime, metadata)
                self.assertEqual(concurrency['cancel-in-progress'], 'true')
            groups.append(runtime)
        self.assertEqual(len(set(groups)), 2)

    def test_ref_wide_or_cross_workflow_cancellation_is_rejected(self):
        for name, prefix in (('build-server.yaml', 'server-build'), ('native-master.yaml', 'native-master')):
            for group in (prefix + '-${{ github.ref }}', '${{ github.sha }}',
                          'shared-${{ github.ref }}-${{ github.sha }}'):
                value = copy.deepcopy(self.workflows)
                value[name]['concurrency']['group'] = group
                with self.subTest(workflow=name, group=group), self.assertRaises(ValueError):
                    workflow.validate(value)

    def test_only_qualified_bundle_enters_its_non_cancellable_signer_queue(self):
        bundle = self.workflows['build-server.yaml']['jobs']['bundle']
        self.assertEqual(bundle.get('concurrency'), {
            'group': 'trusted-server-bundle-${{ github.repository }}', 'cancel-in-progress': 'false'})
        self.assertEqual(bundle['if'], workflow.MASTER + " && needs.changes.outputs.server_release_impact == 'true'")
        self.assertNotIn('concurrency', self.workflows['build-server.yaml']['jobs']['changes'])
        self.assertNotIn('concurrency', self.workflows['build-server.yaml']['jobs']['server-quality'])

    def test_missing_cancellable_or_source_split_signer_queue_is_rejected(self):
        for lock in (None, {'group': 'trusted-server-bundle-${{ github.repository }}', 'cancel-in-progress': 'true'},
                     {'group': 'trusted-server-bundle-${{ github.sha }}', 'cancel-in-progress': 'false'}):
            value = copy.deepcopy(self.workflows)
            bundle = value['build-server.yaml']['jobs']['bundle']
            if lock is None:
                bundle.pop('concurrency', None)
            else:
                bundle['concurrency'] = lock
            with self.subTest(lock=lock), self.assertRaises(ValueError):
                workflow.validate(value)

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
            if mutation == 'bundle':
                next(s for s in build['steps'] if s.get('with',{}).get('name','').startswith('server-${{'))['with']['name'] = 'server-${{ github.sha }}'
            if mutation == 'smoke':
                for step in value['ci-backend.yaml']['jobs']['load']['steps']:
                    if step.get('with', {}).get('name', '').startswith('backend-load-smoke-'):
                        step['with']['name'] = 'backend-load-smoke-${{ github.sha }}'
            if mutation in ('download', 'retained'):
                name = 'deploy-production.yaml' if mutation == 'download' else 'install-retained-release.yaml'
                value[name]['jobs']['install']['steps'][-1]['with']['build-run-id'] = '${{ github.run_id }}'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): workflow.validate(value)

    def test_every_server_upload_is_attempt_bound_including_load_smoke(self):
        for name in ('build-server.yaml', 'ci-backend.yaml', 'ci-frontend.yaml', 'ci-contracts.yaml'):
            for job in self.workflows[name]['jobs'].values():
                for step in job.get('steps', []):
                    if step.get('uses') == 'actions/upload-artifact@v7':
                        artifact = step['with']['name']
                        for field in ('sha', 'run_id', 'run_attempt'):
                            self.assertIn('${{ github.' + field + ' }}', artifact)

    def test_builder_downloads_same_run_receipt_attempts_and_selects_latest_validated_set(self):
        steps = self.workflows['build-server.yaml']['jobs']['bundle']['steps']
        downloads = [s for s in steps if s.get('uses') == 'actions/download-artifact@v8']
        execution = '${{ github.sha }}-${{ github.run_id }}-*'
        self.assertEqual([{'pattern': 'check-{backend,web,contracts}-' + execution,
                           'path': '.out/gate-artifacts', 'merge-multiple': 'false'}],
                         [s['with'] for s in downloads])
        self.assertTrue(all(not s.get('if') for s in downloads))
        collector = next(step for step in steps if step.get('run', '').startswith('python3 -m tools.build.server.gate_receipts'))
        self.assertEqual('python3 -m tools.build.server.gate_receipts --collect .out/gate-artifacts .out/checks', collector['run'])
        self.assertEqual({'GATE_SOURCE_REVISION': '${{ github.sha }}', 'GATE_RUN_ID': '${{ github.run_id }}',
                          'GATE_RUN_ATTEMPT': '${{ github.run_attempt }}'}, collector['env'])

    def test_bundle_selects_and_verifies_its_reviewed_python_before_running_collector(self):
        steps = self.workflows['build-server.yaml']['jobs']['bundle']['steps']
        setup = next(step for step in steps if step.get('uses') == 'actions/setup-python@v7')
        verify = next(step for step in steps if step.get('run') == 'python -m tools.ci.toolchains.runtime python')
        collector = next(step for step in steps if step.get('run', '').startswith('python3 -m tools.build.server.gate_receipts'))
        self.assertEqual({'python-version': '${{ runner.os == \'Linux\' && \'3.12.15\' || \'3.12.10\' }}'}, setup['with'])
        self.assertLess(steps.index(setup), steps.index(verify))
        self.assertLess(steps.index(verify), steps.index(collector))
        for mutation in ('missing-setup', 'missing-check', 'late-check'):
            broken = copy.deepcopy(self.workflows)
            target = broken['build-server.yaml']['jobs']['bundle']['steps']
            if mutation == 'missing-setup': target.remove(next(step for step in target if step.get('uses') == 'actions/setup-python@v7'))
            if mutation == 'missing-check': target.remove(next(step for step in target if step.get('run') == 'python -m tools.ci.toolchains.runtime python'))
            if mutation == 'late-check':
                check = next(step for step in target if step.get('run') == 'python -m tools.ci.toolchains.runtime python')
                target.remove(check); target.insert(target.index(next(step for step in target if step.get('run', '').startswith('python3 -m tools.build.server.gate_receipts')))+1, check)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): workflow.validate(broken)
