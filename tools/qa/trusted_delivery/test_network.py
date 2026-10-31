"""A live downloader proof must use the shipping path and never claim an install."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import network

SHA = 'a' * 40
CONTROLLER = 'b' * 40
ENV = {'GITHUB_REPOSITORY': 'BOOHTACORD/BOOHTACORD', 'BUILD_RUN_ID': '123',
       'REQUESTED_REVISION': SHA, 'GITHUB_TOKEN': 'secret-token-canary'}


class NetworkProofTests(unittest.TestCase):
    def probe(self, root, failure=None):
        calls = []
        def prepare(snapshot, output):
            calls.append('prepare')
            snapshot.write_text(json.dumps({'id': 44, 'source_revision': SHA}))
        def download():
            calls.append('download')
            if failure == 'download': raise ValueError('secret-url-canary')
            target = Path.cwd()/'.out/delivery/download.json'
            target.write_text(json.dumps({'outer_digest': 'verified', 'archive_bytes': 40,
                                         'bundle_sha256': 'c'*64, 'bundle_bytes': 30}))
        def recheck(snapshot, incoming):
            calls.append('recheck')
            if failure == 'recheck': raise ValueError('secret-token-canary')
            return {'id': 44, 'source_revision': SHA, 'run_id': 123, 'run_attempt': 1,
                    'digest': 'sha256:'+'d'*64, 'size_in_bytes': 40, 'extra': 'secret-extra-canary'}
        with patch.dict(os.environ, ENV, clear=True), patch.object(network.authority, 'prepare', prepare), \
                patch.object(network.download, 'main', download), patch.object(network.authority, 'recheck', recheck):
            if failure:
                with self.assertRaises(ValueError): network.probe(root, CONTROLLER)
            else:
                network.probe(root, CONTROLLER)
        return calls, json.loads((root/'evidence.json').read_text())

    def test_shipping_order_fresh_authority_and_no_signature_or_install_claim(self):
        original = Path.cwd()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()/'proof'
            calls, result = self.probe(root)
            self.assertEqual(['prepare', 'download', 'recheck'], calls)
            self.assertEqual('PASS', result['status'])
            self.assertEqual(CONTROLLER, result['controller_revision'])
            self.assertEqual(SHA, result['producer']['source_revision'])
            self.assertEqual('NOT_RUN', result['installation'])
            self.assertEqual('NOT_RUN', result['host_signature'])
            self.assertNotIn('canary', json.dumps(result))
        self.assertEqual(original, Path.cwd())

    def test_failed_download_or_changed_producer_never_leaves_green_or_private_error(self):
        for failure in ('download', 'recheck'):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as tmp:
                calls, result = self.probe(Path(tmp).resolve()/'proof', failure)
                self.assertEqual('FAIL', result['status'])
                self.assertNotIn('canary', json.dumps(result))
                if failure == 'download': self.assertNotIn('recheck', calls)

    def test_foreign_identity_or_reused_directory_cannot_start_network(self):
        for key, value in [('GITHUB_REPOSITORY', 'foreign/repo'), ('BUILD_RUN_ID', '0'),
                           ('REQUESTED_REVISION', 'master')]:
            with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {**ENV, key: value}, clear=True), \
                    patch.object(network.authority, 'prepare') as prepare, self.assertRaises(ValueError):
                network.probe(Path(tmp).resolve()/'proof', CONTROLLER)
            prepare.assert_not_called()
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, ENV, clear=True), \
                patch.object(network.authority, 'prepare') as prepare, self.assertRaises(FileExistsError):
            network.probe(Path(tmp).resolve(), CONTROLLER)
        prepare.assert_not_called()
