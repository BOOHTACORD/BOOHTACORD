import copy
from pathlib import Path
import unittest
import yaml
from .shadow_workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class ShadowWorkflowTests(unittest.TestCase):
    def document(self):
        return yaml.load((ROOT/'.github/workflows/backend-ci-shadow.yaml').read_text(),Loader=yaml.BaseLoader)

    def test_read_only_pair_uses_original_full_coverage_and_unchanged_normal_fanout(self):
        validate(self.document())

    def test_new_privileges_source_bypass_ignored_failure_or_foreign_artifact_are_rejected(self):
        for change in ('permissions','trigger','source','failure','database','callee','artifact',
                       'late-invalidation','early-measure','skip-checkout','extra-command','skip-sdk','hosted-runner'):
            value=copy.deepcopy(self.document());jobs=value['jobs']
            if change=='permissions':value['permissions']['contents']='write'
            if change=='trigger':value['on']['push']={}
            if change=='source':jobs['legacy']['if']='true'
            if change=='failure':jobs['legacy']['continue-on-error']='true'
            if change=='database':jobs['legacy'].pop('services')
            if change=='callee':jobs['profiles']['uses']='foreign/ci@master'
            if change=='artifact':
                next(s for s in jobs['compare']['steps'] if s.get('with',{}).get('name','').startswith('backend-shadow-legacy-'))['with']['name']='foreign-artifact'
            if change=='late-invalidation':
                steps=jobs['compare']['steps']; step=steps.pop(3);steps.insert(5,step)
            if change=='early-measure':
                steps=jobs['compare']['steps']; step=steps.pop(-2);steps.insert(4,step)
            if change=='skip-checkout':jobs['legacy']['steps'][0]['if']='false'
            if change=='extra-command':jobs['legacy']['steps'].insert(-1,{'run':'true'})
            if change=='skip-sdk':jobs['legacy']['steps'][4]['if']='false'
            if change=='hosted-runner':jobs['legacy']['runs-on']='ubuntu-24.04'
            with self.subTest(change=change),self.assertRaises(ValueError):validate(value)
