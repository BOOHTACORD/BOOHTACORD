"""The backend aggregate cannot omit a job or accept another execution."""
import copy
from pathlib import Path
import unittest
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class WorkflowTests(unittest.TestCase):
    def document(self):
        return yaml.load((ROOT/'.github/workflows/ci-backend.yaml').read_text(),Loader=yaml.BaseLoader)

    def test_actual_parallel_gate(self): validate(self.document())

    def test_database_events_cannot_be_missing_optional_or_foreign(self):
        for mutation in ('missing', 'optional', 'ignored', 'foreign'):
            value=self.document(); steps=value['jobs']['database']['steps']
            step=next(s for s in steps if s.get('with',{}).get('path') == '.out/checks/backend.jsonl')
            if mutation == 'missing': steps.remove(step)
            elif mutation == 'optional': step['if']='success()'
            elif mutation == 'ignored': step['with']['if-no-files-found']='ignore'
            else: step['with']['name']='backend-events-another-source'
            with self.subTest(mutation=mutation),self.assertRaises(ValueError): validate(value)

    def test_skips_optional_jobs_database_loss_foreign_artifacts_and_receipt_bypass_fail(self):
        for change in ('skip','ignore','database','shared-database','needs','foreign','receipt','status','matrix'):
            value=copy.deepcopy(self.document()); jobs=value['jobs']
            if change == 'skip': jobs['static']['if']='false'
            if change == 'ignore': jobs['load']['continue-on-error']='true'
            if change == 'database': jobs['database'].pop('services')
            if change == 'shared-database': jobs['load']['services']=jobs['database']['services']
            if change == 'needs': jobs['backend']['needs'].pop()
            if change == 'matrix': jobs['static']['strategy']={'matrix':{'x':['1']}}
            for step in jobs['backend']['steps']:
                if change == 'foreign' and 'download-artifact' in step.get('uses',''): step['with']['pattern']='backend-part-*'
                if 'tools.ci.receipts.run' in step.get('run',''):
                    if change == 'receipt': step['if']='false'
                    if change == 'status': step['env']['BACKEND_NEEDS']='{}'
            with self.subTest(change=change),self.assertRaises(ValueError): validate(value)
