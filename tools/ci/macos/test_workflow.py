import copy
from pathlib import Path
import unittest
import yaml
from .workflow import validate

ROOT=Path(__file__).resolve().parents[3]


class MacWorkflowTests(unittest.TestCase):
    def setUp(self):self.docs={p.name:yaml.load(p.read_text(),Loader=yaml.BaseLoader) for p in (ROOT/'.github/workflows').glob('*.yaml')}

    def test_hosted_explicit_native_and_separate_publication(self):validate(self.docs)

    def test_build_and_release_require_vendor_execution_and_retained_results(self):
        for filename, name in (('flutter-macos.yaml', 'macos'), ('macos-release.yaml', 'macos-release')):
            for mutation in ('missing', 'optional', 'ignored', 'upload'):
                docs = copy.deepcopy(self.docs); steps = docs[filename]['jobs'][name]['steps']
                step = next(s for s in steps if s.get('run') == 'python3 -m tools.verify.macos_unit.run')
                if mutation == 'missing': steps.remove(step)
                elif mutation == 'optional': step['if'] = 'false'
                elif mutation == 'ignored': step['continue-on-error'] = 'true'
                else: next(s for s in steps if s.get('with', {}).get('path') == '.out/checks/macos-unit/')['with']['if-no-files-found'] = 'ignore'
                with self.subTest(filename=filename, mutation=mutation), self.assertRaises(ValueError): validate(docs)

    def test_missing_arch_stale_artifact_or_untrusted_publish_never_passes(self):
        for mode in ('arch','input','cleanup','publish','self-hosted'):
            docs=copy.deepcopy(self.docs);sdk=docs['webrtc-macos-sdk.yaml']
            if mode=='arch':sdk['jobs']['build']['strategy']['matrix']['include'].pop()
            if mode=='input':
                next(s for s in sdk['jobs']['assemble']['steps'] if s.get('with',{}).get('path')=='.out/sdk-inputs/arm64')['with']['name']='sdk-arm64'
            if mode=='cleanup':
                next(s for s in sdk['jobs']['build']['steps'] if 'webrtc_macos.execution' in s.get('run',''))['if']='success()'
            if mode=='publish':sdk['jobs']['publish']['if']='true'
            if mode=='self-hosted':docs['flutter-macos.yaml']['jobs']['macos']['runs-on']=['self-hosted','macos']
            with self.subTest(mode=mode),self.assertRaises(ValueError):validate(docs)
