"""Auxiliary SDK declarations must be exact; host defaults do not attest a pin."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
import yaml
from . import auxiliary

ROOT = Path(__file__).resolve().parents[3]


class AuxiliaryTests(unittest.TestCase):
    def documents(self):
        return {p.name: yaml.load(p.read_text(), Loader=yaml.BaseLoader)
                for p in (ROOT / '.github/workflows').glob('*.yaml')}

    def test_actual_committed_sources_and_workflows_agree(self):
        auxiliary.audit(ROOT)
        auxiliary.validate_workflows(self.documents(), ROOT)

    def test_loose_or_foreign_auxiliary_sdk_is_rejected(self):
        examples = [('actions/setup-python@', 'python-version', '3.12'),
                    ('actions/setup-java@', 'java-version', '17'),
                    ('actions/setup-dotnet@', 'dotnet-version', '8.0.x')]
        for action, key, bad in examples:
            with self.subTest(action=action):
                documents = self.documents()
                step = next(s for w in documents.values() for j in w['jobs'].values()
                            for s in j.get('steps', []) if s.get('uses', '').startswith(action))
                step['with'][key] = bad
                with self.assertRaises(ValueError): auxiliary.validate_workflows(documents, ROOT)

    def test_wrong_java_vendor_and_conditional_sdk_are_rejected(self):
        for mutation in ('vendor', 'conditional'):
            docs = self.documents()
            step = next(s for w in docs.values() for j in w['jobs'].values()
                        for s in j.get('steps', []) if s.get('uses', '').startswith('actions/setup-java@'))
            if mutation == 'vendor': step['with']['distribution'] = 'foreign'
            else: step['if'] = "steps.cache.outputs.cache-hit != 'true'"
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                auxiliary.validate_workflows(docs, ROOT)

    def test_missing_interpreter_or_runtime_check_is_rejected(self):
        for remove in ('setup', 'runtime'):
            docs = self.documents()
            steps = docs['ci-flutter.yaml']['jobs']['flutter']['steps']
            target = next(s for s in steps if (s.get('uses', '').startswith('actions/setup-python@')
                          if remove == 'setup' else s.get('run') == 'python -m tools.ci.toolchains.runtime python'))
            steps.remove(target)
            with self.subTest(remove=remove), self.assertRaises(ValueError):
                auxiliary.validate_workflows(docs, ROOT)

    def test_native_input_drift_missing_or_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            manifest = json.loads((ROOT / 'tools/ci/toolchains/native-inputs.json').read_text())
            files = ['tools/ci/toolchains/auxiliary.json', 'tools/ci/flutter_setup/vendor-locks.json',
                     'tools/ci/flutter_setup/locks/livekit_client.lock', 'tools/ci/flutter_setup/locks/flutter_webrtc.lock',
                     'clients/flutter/packages/livekit_client/pubspec.yaml', 'clients/flutter/packages/flutter_webrtc/pubspec.yaml',
                     'tools/toolchains.json', 'tools/ci/toolchains/native-inputs.json', *manifest['files']]
            for name in files:
                path = root / name; path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((ROOT / name).read_bytes())
            auxiliary.audit(root)
            for name in manifest['files']:
                path = root / name; path.write_bytes(path.read_bytes().replace(b'\n', b'\r\n'))
            auxiliary.audit(root)
            name = next(iter(manifest['files'])); path = root / name
            original = path.read_bytes(); path.write_bytes(original + b'\n')
            with self.assertRaises(ValueError): auxiliary.audit(root)
            path.unlink()
            with self.assertRaises(ValueError): auxiliary.audit(root)
            target = root / 'indirect'; target.write_bytes(original); path.symlink_to(target)
            with self.assertRaises(ValueError): auxiliary.audit(root)

    def test_runtime_versions_are_checked_not_assumed_from_cache(self):
        auxiliary.check_runtime('python', '3.12.15', 'Linux', ROOT)
        auxiliary.check_runtime('python', '3.12.10', 'Windows', ROOT)
        auxiliary.check_runtime('dotnet', '8.0.426', 'Windows', ROOT)
        auxiliary.check_runtime('java', '17.0.20+1', 'Linux', ROOT)
        for kind, value, system in [('python', '3.12.10', 'Linux'), ('java', '17.0.20+2', 'Linux'),
                                    ('dotnet', '8.0.425', 'Windows'), ('python', '3.12.15', 'foreign')]:
            with self.subTest(kind=kind, value=value), self.assertRaises(ValueError):
                auxiliary.check_runtime(kind, value, system, ROOT)
