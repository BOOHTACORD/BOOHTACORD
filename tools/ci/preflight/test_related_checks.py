import unittest
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from unittest.mock import patch

from tools.ci.preflight.related_checks import checks


class RelatedChecksTest(unittest.TestCase):
    def test_contract_fixture_failure_blocks_only_applicable_diff(self):
        with patch('tools.ci.preflight.related_checks.check') as run:
            run.return_value = {'status': 'FAIL', 'reason': 'missing fixture'}
            result = checks('.', ['contracts/openapi.yaml'])
            self.assertEqual(result['contracts']['status'], 'FAIL')
            self.assertEqual(result['traceability']['status'], 'N/A')
            self.assertIn('verify-contracts.ps1', ' '.join(run.call_args.args[1]))

    def test_unavailable_approved_brief_is_blocked(self):
        with patch('tools.ci.preflight.related_checks.approved_brief', return_value=False):
            result = checks('.', ['backlog/tasks.yaml'])
        self.assertEqual(result['traceability']['status'], 'BLOCKED')
        self.assertIn('VOICE_PLATFORM_APPROVED_SPEC_PATH', result['traceability']['reason'])

    def test_unrelated_diff_does_not_run_heavy_checks(self):
        with patch('tools.ci.preflight.related_checks.check') as run:
            result = checks('.', ['docs/readme.md'])
        self.assertEqual({v['status'] for v in result.values()}, {'N/A'})
        run.assert_not_called()

    @unittest.skipUnless(shutil.which('pwsh'), 'PowerShell is unavailable')
    def test_real_contract_verifier_rejects_missing_fixture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'tools/verify/contracts'
            scripts.mkdir(parents=True)
            source = Path(__file__).resolve().parents[3] / 'tools/verify/contracts/verify-contracts.ps1'
            shutil.copyfile(source, scripts / source.name)
            contracts = root / 'contracts'
            contracts.mkdir()
            for name in ('openapi.yaml', 'realtime.schema.json', 'desktop-update-artifact.schema.json',
                         'client-release-catalog.schema.json'):
                (contracts / name).write_text('{}', encoding='utf-8')
            result = checks(root, ['contracts/client-update-evaluator.fixtures.json'])
            self.assertEqual(result['contracts']['status'], 'FAIL')
            output = subprocess.run(result['contracts']['command'], cwd=root, capture_output=True)
            self.assertIn(b'client-update-evaluator.fixtures.json', output.stderr)

    @unittest.skipUnless(shutil.which('pwsh'), 'PowerShell is unavailable')
    def test_real_traceability_verifier_rejects_missing_backlog_reference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = root / 'tools/verify/spec_traceability'
            scripts.mkdir(parents=True)
            source = Path(__file__).resolve().parents[3] / 'tools/verify/spec_traceability/verify-spec-traceability.ps1'
            shutil.copyfile(source, scripts / source.name)
            requirements = [f'REQ-TEST-{i:02d}' for i in range(1, 40)]
            brief = root / 'approved.md'
            brief.write_text(''.join(f'### {item}.\n' for item in requirements), encoding='utf-8')
            backlog = root / 'backlog'
            backlog.mkdir()
            (backlog / 'approved-requirements.json').write_text(json.dumps({
                'requirement_ids': requirements, 'source_sha256': hashlib.sha256(brief.read_bytes()).hexdigest()}))
            (backlog / 'tasks.yaml').write_text('\n'.join(requirements[:-1]))
            with patch.dict(os.environ, {'VOICE_PLATFORM_APPROVED_SPEC_PATH': str(brief)}):
                result = checks(root, ['backlog/tasks.yaml'])
                self.assertEqual(result['traceability']['status'], 'FAIL')
                output = subprocess.run(result['traceability']['command'], cwd=root, capture_output=True)
            self.assertIn(b'REQ-TEST-39', output.stderr)


if __name__ == '__main__':
    unittest.main()
