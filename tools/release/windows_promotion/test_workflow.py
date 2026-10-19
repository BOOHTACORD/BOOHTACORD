"""Promotion scopes, exact CI and read-only post-deploy tracing are mandatory."""
from pathlib import Path
import unittest
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class WorkflowTests(unittest.TestCase):
    def documents(self):return {p.name:yaml.load(p.read_text(),Loader=yaml.BaseLoader) for p in (ROOT/'.github/workflows').glob('*.yaml')}
    def test_actual_graph(self):validate(self.documents())
    def test_no_combined_write_scopes_ci_skip_automerge_or_mutating_readback(self):
        for change in ('scopes','ci','needs','automerge','readback','intent'):
            d=self.documents();jobs=d['promote-windows-client-update.yaml']['jobs']
            if change=='scopes':jobs['prepare-catalog-pr']['permissions']['actions']='write'
            if change=='needs':jobs['prepare-catalog-pr']['needs'].remove('candidate-ci')
            if change=='automerge':jobs['prepare-catalog-pr']['steps'].append({'run':'gh pr merge --auto'})
            if change=='ci':next(s for s in jobs['candidate-ci']['steps'] if 'candidate_ci' in s.get('run',''))['if']='false'
            if change=='readback':d['windows-promotion-readback.yaml']['jobs']['readback']['environment']='production'
            if change=='intent':next(s for s in d['ci-contracts.yaml']['jobs']['contracts']['steps'] if 'windows_promotion.check_source' in s.get('run',''))['if']='false'
            with self.subTest(change=change),self.assertRaises(ValueError):validate(d)
