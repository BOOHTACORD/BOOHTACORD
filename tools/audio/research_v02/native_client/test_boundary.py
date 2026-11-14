"""The native research backend must not build in CI or with unverified source."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / 'clients/flutter/packages/flutter_webrtc/common/rnnoise'


class ResearchBuildBoundaryTest(unittest.TestCase):
    def configure(self, source, *, ci, local=True, extra=()):
        with tempfile.TemporaryDirectory() as directory:
            env = dict(os.environ, BOOHTA_RNNOISE_V02_SOURCE=str(source),
                       BOOHTA_RNNOISE_LOCAL_ONLY='1' if local else '0')
            if ci: env['CI'] = 'true'
            else:
                env.pop('CI', None)
                env.pop('GITHUB_ACTIONS', None)
            return subprocess.run(['cmake', '-S', str(SOURCE), '-B', directory, *extra],
                                  env=env, capture_output=True, text=True, timeout=90)

    def test_missing_research_source_fails_closed(self):
        result = self.configure(ROOT / '.out/nonexistent-research-source', ci=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('source identity verification failed', (result.stdout + result.stderr).lower())

    def test_research_backend_is_forbidden_in_ci(self):
        result = self.configure(ROOT / '.out/nonexistent-research-source', ci=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('local-only', (result.stdout + result.stderr).lower())

    def test_source_flag_alone_does_not_enable_local_research(self):
        result = self.configure(ROOT / '.out/nonexistent-research-source', ci=False, local=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('local-only', (result.stdout + result.stderr).lower())

    def test_explicit_install_outside_build_is_rejected_before_source_check(self):
        result = self.configure(ROOT / '.out/nonexistent-research-source', ci=False,
                                extra=('-DBINARY_NAME=probe', '-DCMAKE_INSTALL_PREFIX=' + ROOT.as_posix()))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unsafe research install prefix', (result.stdout + result.stderr).lower())


if __name__ == '__main__':
    unittest.main()
