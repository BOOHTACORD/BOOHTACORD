"""Read-only routing cannot consume or replace a pending production writer."""
import copy
from pathlib import Path
import unittest
import yaml
from tools.verify.action_pins.policy import normalized
from tools.verify.workflows.delivery import check

GROUP = 'v-bootybay-production'
ROOT = Path(__file__).resolve().parents[3]


def locks(workflow, job):
    # Workflow and job concurrency are independent locks, not overrides.
    return [value for value in (workflow.get('concurrency'), job.get('concurrency'))
            if isinstance(value, dict)]


class ProductionQueueBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.workflows = {path.name: yaml.load(normalized(path.read_text()), Loader=yaml.BaseLoader)
                          for path in (ROOT / '.github/workflows').glob('*.yaml')}

    def test_no_bundle_reader_cannot_replace_a_pending_production_writer(self):
        workflow = self.workflows['deploy-production.yaml']
        self.assertNotIn(GROUP, [value.get('group') for value in locks(workflow, workflow['jobs']['route'])],
                         'Read-only route runs before bundle qualification and must not enter the writer queue')

    def test_all_existing_production_writers_keep_the_same_non_cancellable_lock(self):
        count = 0
        for name in ('deploy-production.yaml', 'install-retained-release.yaml', 'rehearse-compatible-rollback.yaml', 'qa11-preflight.yaml'):
            workflow = self.workflows[name]
            for job in workflow['jobs'].values():
                if job.get('environment') == 'production':
                    writer_locks = [value for value in locks(workflow, job) if value.get('group') == GROUP]
                    self.assertTrue(writer_locks, name)
                    self.assertTrue(all(value.get('cancel-in-progress') == 'false' for value in writer_locks), name)
                    count += 1
        self.assertEqual(4, count)

    def test_workflow_policy_rejects_a_reader_joining_the_writer_queue(self):
        broken = copy.deepcopy(self.workflows)
        broken['deploy-production.yaml']['jobs']['route']['concurrency'] = {
            'group': GROUP, 'cancel-in-progress': 'false'}
        with self.assertRaises(ValueError):
            check(broken)

    def test_workflow_policy_rejects_an_unlocked_or_cancellable_installer(self):
        for lock in (None, {'group': 'another-writer', 'cancel-in-progress': 'false'},
                     {'group': GROUP, 'cancel-in-progress': 'true'}):
            broken = copy.deepcopy(self.workflows)
            installer = broken['deploy-production.yaml']['jobs']['install']
            if lock is None:
                installer.pop('concurrency', None)
            else:
                installer['concurrency'] = lock
            with self.subTest(lock=lock), self.assertRaises(ValueError):
                check(broken)

    def test_additional_production_job_cannot_escape_the_shared_writer_lock(self):
        broken = copy.deepcopy(self.workflows)
        broken['deploy-production.yaml']['jobs']['another-writer'] = {
            'environment': 'production', 'runs-on': 'ubuntu-24.04',
            'steps': [{'run': 'echo controlled-policy-fixture'}]}
        with self.assertRaises(ValueError):
            check(broken)
