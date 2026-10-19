"""Shadow sampling must stay finite, same-source, hosted and read-only."""
from pathlib import Path
import unittest
import yaml
from . import shadow_workflow

ROOT=Path(__file__).resolve().parents[3]


def document():
    return yaml.load((ROOT/'.github/workflows/web-ci-shadow.yaml').read_text(),Loader=yaml.BaseLoader)


class ShadowWorkflowTests(unittest.TestCase):
    def test_actual_shadow_preserves_all_three_controls_and_qualified_profiles(self):
        shadow_workflow.validate(document())

    def test_mutating_partial_or_unqualified_samples_are_not_allowed(self):
        for change in ('write','sample','parallel','trigger','receipt','namespace','needs','skip'):
            value=document()
            if change=='write':value['permissions']['contents']='write'
            if change=='sample':value['jobs']['legacy']['strategy']['matrix']['sample'].pop()
            if change=='parallel':value['jobs']['profiles']['strategy']['max-parallel']='3'
            if change=='trigger':value['on']['pull_request']=None
            if change=='receipt':value['jobs']['profiles']['with']['release_receipt']='true'
            if change=='namespace':value['jobs']['profiles']['with']['evidence_namespace']='web'
            if change=='needs':value['jobs']['compare']['needs'].pop()
            if change=='skip':
                for s in value['jobs']['legacy']['steps']:
                    if s.get('run')=='python3 -m tools.ci.web_suites.legacy':s['if']='false'
            with self.subTest(change=change),self.assertRaises(ValueError):shadow_workflow.validate(value)
