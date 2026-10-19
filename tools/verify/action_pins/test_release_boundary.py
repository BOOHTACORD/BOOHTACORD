"""Exercise existing release rejection boundaries with disposable keys and canaries."""
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from tools.release.bundle.signature import sign, verify
from tools.release.delivery.provenance import main


class ReleaseBoundaryTests(unittest.TestCase):
    def test_unsigned_and_foreign_signed_manifests_fail_without_logging_private_text(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            openssl = shutil.which('openssl') or r'C:\Program Files\Git\usr\bin\openssl.exe'
            keys = [root / name for name in ('trusted.pem', 'foreign.pem')]
            for key in keys:
                subprocess.run([openssl, 'genpkey', '-algorithm', 'RSA', '-pkeyopt',
                    'rsa_keygen_bits:2048', '-out', str(key)], check=True, capture_output=True)
            public = root / 'trusted-public.pem'
            subprocess.run([openssl, 'pkey', '-in', str(keys[0]), '-pubout',
                '-out', str(public)], check=True, capture_output=True)
            manifest = root / 'manifest.json'
            manifest.write_text('synthetic-private-payload-canary')
            for foreign_signed in (False, True):
                if foreign_signed: sign(manifest, keys[1], openssl=openssl)
                stdout, stderr = StringIO(), StringIO()
                with redirect_stdout(stdout), redirect_stderr(stderr):
                    with self.assertRaisesRegex(ValueError, '^Release manifest signature does not match the trusted host key$'):
                        verify(manifest, public, openssl=openssl)
                self.assertEqual(stdout.getvalue() + stderr.getvalue(), '')

    def test_foreign_producer_cannot_emit_receipt_or_leak_response_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'output'
            env = {'GITHUB_REPOSITORY': 'Egkurilov/BOOHTACORD', 'BUILD_RUN_ID': '123',
                   'GITHUB_TOKEN': 'synthetic-session-canary', 'GITHUB_OUTPUT': str(output)}
            response = {'head_sha': 'a' * 40, 'head_repository': {'full_name': 'foreign/repo'},
                        'private_payload': 'synthetic-message-canary'}
            stdout, stderr = StringIO(), StringIO()
            with patch.dict(os.environ, env, clear=True), patch('tools.release.delivery.api.urlopen') as opened:
                opened.return_value.__enter__.return_value = StringIO(json.dumps(response))
                with redirect_stdout(stdout), redirect_stderr(stderr):
                    with self.assertRaisesRegex(ValueError, '^Foreign build repository$'): main()
            self.assertFalse(output.exists())
            self.assertEqual(stdout.getvalue() + stderr.getvalue(), '')
