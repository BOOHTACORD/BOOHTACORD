"""All stable publishers must share source/assets guards and explicit candidate mode."""
import unittest
from pathlib import Path
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class WorkflowTests(unittest.TestCase):
    def documents(self):return {p.name:yaml.load(p.read_text(),Loader=yaml.BaseLoader) for p in (ROOT/'.github/workflows').glob('*.yaml')}
    def test_current_contracts(self):validate(self.documents())
    def test_stable_mac_master_dispatch_is_not_filtered_to_candidates(self):
        job=self.documents()['macos-release.yaml']['jobs']['macos-release']
        self.assertIn("github.ref == 'refs/heads/master' && github.event_name == 'workflow_dispatch'",job['if'])
        self.assertNotIn('inputs.dry_run',job['if'])

    def test_native_job_source_guard_cannot_be_skipped_or_silently_restricted(self):
        for platform in ('android','windows','macos'):
            for change in ('false','true','foreign-source','candidate-only'):
                d=self.documents();job=d[platform+'-release.yaml']['jobs'][platform+'-release']
                if change in ('false','true'):job['if']=change
                elif change=='foreign-source':job['if']+=' || true'
                else:job['if']+=' && inputs.dry_run'
                with self.subTest(platform=platform,change=change),self.assertRaises(ValueError):validate(d)
    def test_source_skip_foreign_publisher_missing_manifest_and_candidate_bypass_fail(self):
        for change in ('source','fetch','assets','publisher','dry-run','retention','legacy','replacement','environment'):
            d=self.documents();job=d['android-release.yaml']['jobs']['android-release']
            if change=='environment':job['environment']='native-release'
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
