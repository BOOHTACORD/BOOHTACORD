"""All stable publishers must share source/assets guards and explicit candidate mode."""
import unittest
from pathlib import Path
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class WorkflowTests(unittest.TestCase):
    def documents(self):return {p.name:yaml.load(p.read_text(),Loader=yaml.BaseLoader) for p in (ROOT/'.github/workflows').glob('*.yaml')}
    def test_current_contracts(self):validate(self.documents())
    def test_source_skip_foreign_publisher_missing_manifest_and_candidate_bypass_fail(self):
        for change in ('source','fetch','assets','publisher','dry-run','retention','legacy','replacement'):
            d=self.documents();job=d['android-release.yaml']['jobs']['android-release']
            if change=='fetch':next(s for s in job['steps'] if 'checkout@' in s.get('uses',''))['with']['fetch-depth']='1'
            if change=='legacy':d['native-candidate-builds.yaml']={'jobs':{}}
            if change=='replacement':
                unit=d['flutter-windows.yaml']['jobs']['windows-native-unit']
                unit['steps']=[s for s in unit['steps'] if 'windows_paths_test.cpp' not in s.get('run','')]
            for s in job['steps']:
                command=s.get('run','')
                if change=='source' and 'native_contract.run preflight' in command:s['if']='false'
                if change=='assets' and 'native_contract.run assets' in command:s['if']='false'
                if 'native_contract/publish.mjs' in command:
                    if change=='publisher':s['run']='node tools/release/android/publish.mjs'
                    if change=='dry-run':s.pop('if')
                if change=='retention' and s.get('with',{}).get('path')=='.out/native-release/android/':s['with']['retention-days']='1'
            with self.subTest(change=change),self.assertRaises(ValueError):validate(d)
