"""One CI build, mandatory native/recovery/GUI work and exact artifact handoff."""
from pathlib import Path
import unittest
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class WorkflowTests(unittest.TestCase):
    def document(self):return yaml.load((ROOT/'.github/workflows/flutter-windows.yaml').read_text(),Loader=yaml.BaseLoader)
    def test_actual_graph(self):validate(self.document())
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
