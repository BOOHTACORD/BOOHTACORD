"""The reusable Web gate must require every isolated profile before its receipt."""
import copy
from pathlib import Path
import unittest
import yaml
from . import workflow

ROOT = Path(__file__).resolve().parents[3]


def document():
    return yaml.load((ROOT / '.github/workflows/ci-frontend.yaml').read_text(), Loader=yaml.BaseLoader)


class WorkflowTests(unittest.TestCase):
    def test_actual_workflow_has_complete_mandatory_parallel_gate(self):
        workflow.validate(document())

    def test_missing_skip_or_ignored_profile_and_matrix_drift_are_rejected(self):
        for change in ('missing', 'skip', 'ignore', 'matrix', 'upload', 'partial-fail-fast'):
            value = document()
            if change == 'missing': del value['jobs']['sfu']
            if change == 'skip': value['jobs']['fast']['if'] = 'false'
            if change == 'ignore': value['jobs']['browser']['continue-on-error'] = 'true'
            if change == 'matrix': value['jobs']['browser']['strategy']['matrix']['profile'].pop()
            if change == 'partial-fail-fast': value['jobs']['browser']['strategy']['fail-fast'] = 'true'
            if change == 'upload':
                for step in value['jobs']['fast']['steps']:
                    if step.get('uses','').startswith('actions/upload-artifact@'):
                        step['with']['if-no-files-found'] = 'ignore'
            with self.subTest(change=change), self.assertRaises(ValueError): workflow.validate(value)

    def test_receipt_cannot_ignore_failed_jobs_or_consume_foreign_artifacts(self):
        for change in ('if', 'needs', 'namespace', 'status-json', 'receipt'):
            value = document(); job = value['jobs']['frontend']
            if change == 'if': job.pop('if')
            if change == 'needs': job['needs'].pop()
            for step in job['steps']:
                if step.get('uses','').startswith('actions/download-artifact@') and change == 'namespace':
                    step['with']['pattern'] = 'web-part-*'
                if 'tools.ci.receipts.run' in step.get('run',''):
                    if change == 'status-json': step['env']['WEB_NEEDS'] = '{}'
                    if change == 'receipt': step['if'] = 'false'
            with self.subTest(change=change), self.assertRaises(ValueError): workflow.validate(value)
