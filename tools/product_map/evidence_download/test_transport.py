import hashlib
import unittest
from urllib.error import HTTPError
from unittest.mock import patch

from tools.product_map.evidence_download.transport import download_artifact


class Response:
    status = 200
    def __init__(self, data): self.data = data
    def __enter__(self): return self
    def __exit__(self, *_): pass
    def read(self, n): return self.data[:n]


def candidate(raw=b'zip'):
    return {'status': 'CANDIDATE_UNVERIFIED', 'artifact_id': 123,
            'artifact_size': len(raw), 'artifact_digest': 'sha256:' + hashlib.sha256(raw).hexdigest()}


def redirect(location):
    return HTTPError('https://api.github.com/', 302, 'redirect', {'Location': location}, None)


class DownloadTests(unittest.TestCase):
    @patch('tools.product_map.evidence_download.transport.urlopen_no_redirect')
    def test_download_checks_digest_without_forwarding_token(self, opener):
        opener.side_effect = [redirect('https://x.blob.core.windows.net/data?sig=secret'), Response(b'zip')]
        self.assertEqual(download_artifact(candidate(), 'ghs_dummy'), b'zip')
        api, blob = [call.args[0] for call in opener.call_args_list]
        self.assertEqual(api.get_header('Authorization'), 'Bearer ghs_dummy')
        self.assertIsNone(blob.get_header('Authorization'))
        self.assertEqual(api.full_url, 'https://api.github.com/repos/BOOHTACORD/BOOHTACORD/actions/artifacts/123/zip')

    @patch('tools.product_map.evidence_download.transport.urlopen_no_redirect')
    def test_rejects_untrusted_redirect_without_leaking_signed_url(self, opener):
        for location in ('http://x.blob.core.windows.net/a?sig=secret',
                         'https://x.blob.core.windows.net.evil.test/a?sig=secret',
                         'https://user@x.blob.core.windows.net/a?sig=secret',
                         'https://127.0.0.1/a?sig=secret'):
            opener.side_effect = redirect(location)
            with self.subTest(location=location.split('?')[0]), self.assertRaises(ValueError) as raised:
                download_artifact(candidate(), 'ghs_dummy')
            self.assertNotIn('secret', str(raised.exception))
            self.assertNotIn('ghs_dummy', str(raised.exception))

    @patch('tools.product_map.evidence_download.transport.urlopen_no_redirect')
    def test_rejects_wrong_bytes_and_explicit_second_redirect(self, opener):
        opener.side_effect = [redirect('https://x.blob.core.windows.net/a'), Response(b'bad')]
        with self.assertRaisesRegex(ValueError, 'digest'):
            download_artifact(candidate(), None)
        opener.side_effect = [redirect('https://x.blob.core.windows.net/a'), redirect('https://evil.test')]
        with self.assertRaises(ValueError):
            download_artifact(candidate(), None)
