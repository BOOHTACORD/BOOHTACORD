import tempfile
import unittest
from pathlib import Path
from tools.ci.preflight.obligations import suspicious
from tools.ci.preflight.run import report


class ReportTest(unittest.TestCase):
    def test_secret_paths_and_runtime_outputs_are_flagged(self):
        for path in ['.env', 'deploy/.env.production', '.out/run.json', 'keys/server.key',
                     'secrets/production.json', '.aws/credentials', '.ssh/id_ed25519']:
            self.assertTrue(suspicious(path), path)
        self.assertFalse(suspicious('.env.example'))
        self.assertFalse(suspicious('evidence/ci/result.json'))

    def test_unavailable_scope_is_blocked(self):
        with tempfile.TemporaryDirectory() as root:
            result = report(Path(root), 'missing')
        self.assertEqual(result['decision'], 'COMMIT_BLOCKED')
        self.assertIn('scope', result['reason'])

    def test_manual_checks_never_default_to_pass(self):
        from tools.ci.preflight.obligations import obligations
        for value in obligations(['docs/example.md']).values():
            self.assertEqual(value['status'], 'BLOCKED')
            self.assertTrue(value['action'])


if __name__ == '__main__':
    unittest.main()
