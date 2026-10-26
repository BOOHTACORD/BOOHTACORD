"""The actual transport proof is read-only and cannot enter the production queue."""
from pathlib import Path
import unittest
import yaml
from tools.verify.action_pins.policy import normalized

ROOT = Path(__file__).resolve().parents[3]


class TrustedDeliveryWorkflowTests(unittest.TestCase):
    def test_actual_transport_has_only_read_authority_and_sanitized_upload(self):
        text = (ROOT/'.github/workflows/qa-trusted-delivery.yaml').read_text()
        document = yaml.load(normalized(text), Loader=yaml.BaseLoader)
        self.assertEqual({'contents': 'read', 'actions': 'read'}, document['permissions'])
        self.assertEqual('qa395-${{ github.ref }}', document['concurrency']['group'])
        job = document['jobs']['network']
        self.assertNotIn('environment', job)
        self.assertEqual('10', job['timeout-minutes'])
        self.assertNotIn('secrets.', text)
        self.assertNotIn('DEPLOY_', text)
        steps = job['steps']
        actual = next(s for s in steps if s.get('run') == 'python -m tools.qa.trusted_delivery.network')
        self.assertNotIn('continue-on-error', actual)
        self.assertEqual({'GITHUB_TOKEN': '${{ github.token }}', 'BUILD_RUN_ID': '39268498370',
                          'REQUESTED_REVISION': 'fe482078a2fa4e4964b6758770980d4b1a0b2fa6'}, actual['env'])
        uploads = [s for s in steps if s.get('uses') == 'actions/upload-artifact@v7']
        self.assertEqual(1, len(uploads))
        self.assertEqual('always()', uploads[0]['if'])
        self.assertEqual({'name': 'qa395-network-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}',
                          'path': '.out/issue395/network/evidence.json', 'retention-days': '30',
                          'if-no-files-found': 'error'}, uploads[0]['with'])
