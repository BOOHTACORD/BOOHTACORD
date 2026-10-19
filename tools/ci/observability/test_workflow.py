import copy
from pathlib import Path
import unittest
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class TriageWorkflowTests(unittest.TestCase):
    def setUp(self):self.docs={p.name:yaml.load(p.read_text(),Loader=yaml.BaseLoader) for p in (ROOT/'.github/workflows').glob('*.yaml')}

    def test_each_root_quality_status_has_always_run_source_bound_triage(self):validate(self.docs)

    def test_pr_checkout_retains_both_test_merge_parents(self):
        import subprocess,tempfile
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'source';source.mkdir()
            def git(*args,cwd=source):
                return subprocess.check_output(['git','-c','core.hooksPath=/dev/null',
                    '-c','commit.gpgsign=false','-c','user.name=CI test',
                    '-c','user.email=ci-test@example.invalid',*args],cwd=cwd,text=True,stderr=subprocess.DEVNULL).strip()
            git('init','-q');git('commit','-qm','base','--allow-empty');git('branch','feature')
            git('commit','-qm','master','--allow-empty');git('switch','-q','feature')
            git('commit','-qm','feature','--allow-empty');feature=git('rev-parse','HEAD')
            git('switch','-q','-');git('merge','--no-ff','--no-edit','feature')
            checkout=next(s for s in self.docs['ci.yaml']['jobs']['ci-required']['steps']
                if s.get('uses','').startswith('actions/checkout@'))
            depth=checkout.get('with',{}).get('fetch-depth','1')
            git('clone','-q','--depth',depth,source.as_uri(),str(root/'checkout'))
            parents=git('show','-s','--format=%P','HEAD',cwd=root/'checkout').split()
            self.assertEqual(2,len(parents));self.assertEqual(feature,parents[1])

    def test_shallow_pr_checkout_cannot_pass_source_binding_policy(self):
        for depth in (None,'1','${{ inputs.depth }}'):
            docs=copy.deepcopy(self.docs)
            checkout=next(s for s in docs['ci.yaml']['jobs']['ci-required']['steps']
                if s.get('uses','').startswith('actions/checkout@'))
            checkout.setdefault('with',{})['fetch-depth']=depth
            with self.subTest(depth=depth),self.assertRaises(ValueError):validate(docs)

    def test_failed_missing_or_conditionally_hidden_diagnostics_never_pass_policy(self):
        for change in ('skip','missing','soft','retention'):
            docs=copy.deepcopy(self.docs);steps=docs['ci.yaml']['jobs']['ci-required']['steps']
            summary=next(s for s in steps if 'observability.summary' in s.get('run',''))
            if change=='skip':summary['if']='success()'
            if change=='missing':steps.remove(summary)
            if change=='soft':summary['continue-on-error']='true'
            if change=='retention':steps[-1]['with']['if-no-files-found']='ignore'
            with self.subTest(change=change),self.assertRaises(ValueError):validate(docs)
