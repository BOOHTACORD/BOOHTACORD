import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from .ci_proof import same_runtime_inputs


class RuntimeInputsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        previous = os.getcwd(); os.chdir(temporary.name); self.addCleanup(os.chdir, previous)
        for args in [('init', '-q'), ('config', 'user.name', 'QA fixture'),
                     ('config', 'user.email', 'fixture@example.invalid')]: self.git(*args)
        for name in ['backend/main.go', 'tools/release/delivery/test_workflows.py',
                     'tools/release/delivery/routing.py', 'tools/release/bundle/test_signature.py',
                     'clients/web/src/main.ts', 'tools/toolchains.json']:
            path = Path(name);path.parent.mkdir(parents=True, exist_ok=True);path.write_text('one')
        self.git('add', 'backend', 'tools', 'clients')
        self.git('commit', '-qm', 'retained source')
        self.base = self.git('rev-parse', 'HEAD')

    def git(self, *args):
        return subprocess.check_output(['git', *args], text=True, stderr=subprocess.DEVNULL).strip()

    def test_only_the_named_non_runtime_workflow_test_adaptor_can_differ(self):
        Path('tools/release/delivery/test_workflows.py').write_text('reviewed action pin inspection')
        self.git('add', 'tools/release/delivery/test_workflows.py');self.git('commit', '-qm', 'test adaptor only')
        self.assertTrue(same_runtime_inputs(self.base, 'HEAD'))

    def test_runtime_sources_toolchains_and_other_test_files_still_fail_closed(self):
        for name in ['backend/main.go', 'tools/release/delivery/routing.py',
                     'tools/release/bundle/test_signature.py', 'clients/web/src/main.ts', 'tools/toolchains.json']:
            path = Path(name);path.write_text('changed')
            self.git('add', name);self.git('commit', '-qm', 'runtime change')
            with self.subTest(name=name):
                self.assertFalse(same_runtime_inputs(self.base, 'HEAD'))
            path.write_text('one')
            self.git('add', name);self.git('commit', '-qm', 'restore fixture')

    def test_unknown_source_is_not_a_match(self):
        self.assertFalse(same_runtime_inputs('f' * 40, 'HEAD'))
