"""One CI build, mandatory native/recovery/GUI work and exact artifact handoff."""
from pathlib import Path
import unittest
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class WorkflowTests(unittest.TestCase):
    def document(self):return yaml.load((ROOT/'.github/workflows/flutter-windows.yaml').read_text(),Loader=yaml.BaseLoader)
    def test_actual_graph(self):validate(self.document())
    def test_publisher_suite_cannot_be_omitted_skipped_or_delayed(self):
        for change in ('missing','conditional','ignored','late','native','windows'):
            d=self.document();steps=d['jobs']['windows-native-unit']['steps']
            step=next(s for s in steps if s.get('run','').startswith('node --test'))
            if change=='missing':steps.remove(step)
            if change=='conditional':step['if']='false'
            if change=='ignored':step['continue-on-error']='true'
            if change=='late':steps.remove(step);steps.append(step)
            if change=='native':step['run']=step['run'].replace(' tools/release/native_contract/publish.test.mjs','')
            if change=='windows':step['run']=step['run'].replace(' tools/release/windows/publish.test.mjs','')
            with self.subTest(change=change),self.assertRaises(ValueError):validate(d)
    def test_cannot_skip_gui_rebuild_client_or_ignore_failure(self):
        for change in ('skip','needs','ignore','rebuild','artifact','gui','unit','aggregate'):
            d=self.document();jobs=d['jobs'];gui=jobs['windows-gui-sfu']
            if change=='skip':gui['if']='false'
            if change=='needs':gui['needs']=[]
            if change=='ignore':gui['continue-on-error']='true'
            if change=='rebuild':gui['steps'].append({'run':'python -m tools.build.windows.run'})
            if change=='artifact':next(s for s in gui['steps'] if 'download-artifact' in s.get('uses',''))['with']['name']='latest'
            if change=='gui':next(s for s in gui['steps'] if 'windows_gates.acceptance' in s.get('run',''))['if']='false'
            if change=='unit':next(s for s in jobs['windows-native-unit']['steps'] if s.get('run')=='python -m tools.ci.native.flutter')['if']='false'
            if change=='aggregate':jobs['windows']['if']='success()'
            with self.subTest(change=change),self.assertRaises(ValueError):validate(d)
