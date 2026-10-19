import copy
from pathlib import Path
import unittest
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class TriageWorkflowTests(unittest.TestCase):
    def setUp(self):self.docs={p.name:yaml.load(p.read_text(),Loader=yaml.BaseLoader) for p in (ROOT/'.github/workflows').glob('*.yaml')}

    def test_each_root_quality_status_has_always_run_source_bound_triage(self):validate(self.docs)

    def test_failed_missing_or_conditionally_hidden_diagnostics_never_pass_policy(self):
        for change in ('skip','missing','soft','retention'):
            docs=copy.deepcopy(self.docs);steps=docs['ci.yaml']['jobs']['ci-required']['steps']
            summary=next(s for s in steps if 'observability.summary' in s.get('run',''))
            if change=='skip':summary['if']='success()'
            if change=='missing':steps.remove(summary)
            if change=='soft':summary['continue-on-error']='true'
            if change=='retention':steps[-1]['with']['if-no-files-found']='ignore'
            with self.subTest(change=change),self.assertRaises(ValueError):validate(docs)
