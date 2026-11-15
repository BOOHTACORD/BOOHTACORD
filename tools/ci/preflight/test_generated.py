import subprocess
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from tools.ci.preflight.generated import check


class GeneratedTest(unittest.TestCase):
    def test_nonzero_drift_is_fail_and_missing_tool_is_blocked(self):
        with patch('tools.ci.preflight.generated.subprocess.run') as run:
            run.return_value = subprocess.CompletedProcess([], 1, b'', b'generated output differs')
            self.assertEqual(check('.', ['generator', '--check'])['status'], 'FAIL')
            run.side_effect = FileNotFoundError()
            self.assertEqual(check('.', ['generator', '--check'])['status'], 'BLOCKED')
            run.side_effect = subprocess.TimeoutExpired('generator', 10)
            self.assertEqual(check('.', ['generator', '--check'])['status'], 'BLOCKED')

    def test_success_is_limited_to_the_named_check(self):
        with patch('tools.ci.preflight.generated.subprocess.run') as run:
            run.return_value = subprocess.CompletedProcess([], 0, b'', b'')
            result = check('.', ['generator', '--check'])
        self.assertEqual(result['status'], 'PASS')
        self.assertEqual(result['command'], ['generator', '--check'])

    def test_successful_negative_fixture_output_is_not_reported_as_missing_tool(self):
        with patch('tools.ci.preflight.generated.subprocess.run') as run:
            run.return_value = subprocess.CompletedProcess([], 0, b'', b'No module named example')
            self.assertEqual(check('.', ['generator'])['reason'], '')

    @unittest.skipUnless(shutil.which('node') and shutil.which('gofmt'), 'Node or gofmt is unavailable')
    def test_real_flow_generator_detects_stale_output(self):
        root = Path(__file__).resolve().parents[3]
        paths = ['tools/observability/flow_contract/generate.mjs', 'contracts/telemetry-flow-v1.json',
                 'contracts/telemetry-flow-v1.fixtures.json', 'backend/internal/observability/flow_contract/generated.go',
                 'clients/web/src/telemetry/flow_contract/generated.ts', 'clients/web/src/telemetry/flow_contract/fixtures.ts',
                 'clients/flutter/lib/src/features/telemetry/flow_contract/generated.dart']
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for name in paths:
                (target / name).parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(root / name, target / name)
            command = ['node', 'tools/observability/flow_contract/generate.mjs', '--check']
            self.assertEqual(check(target, command)['status'], 'PASS')
            (target / paths[-1]).write_text('stale\n', encoding='utf-8')
            self.assertEqual(check(target, command)['status'], 'FAIL')


if __name__ == '__main__':
    unittest.main()
