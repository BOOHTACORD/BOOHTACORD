import json
import unittest
from urllib.error import HTTPError
from unittest.mock import patch

from tools.product_map.release.github_api import NoRedirect, fetch_candidate, read_api
from tools.product_map.release.test_producer import fixture


class Response:
    status = 200
    def __init__(self, value):
        self.data = value
    def __enter__(self): return self
    def __exit__(self, *_): pass
    def read(self, size): return self.data[:size]


class GitHubAPITests(unittest.TestCase):
    @patch('tools.product_map.release.github_api.urlopen_no_redirect')
    def test_credentials_are_sent_only_to_fixed_github_api(self, opener):
        opener.return_value = Response(b'{"id":1}')
        self.assertEqual(read_api('/actions/runs/123', 'ghs_dummy'), {'id': 1})
        request = opener.call_args.args[0]
        self.assertEqual(request.full_url,
                         'https://api.github.com/repos/BOOHTACORD/BOOHTACORD/actions/runs/123')
        self.assertEqual(request.get_header('Authorization'), 'Bearer ghs_dummy')
        for path in ('https://evil.test/', '//evil.test', '/../user', '/x?redirect=x'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                read_api(path, 'ghs_dummy')

    @patch('tools.product_map.release.github_api.urlopen_no_redirect')
    def test_rejects_oversize_duplicate_json_and_redirect(self, opener):
        for payload in (b'x' * 4_000_001, b'{"id":1,"id":2}'):
            opener.return_value = Response(payload)
            with self.subTest(size=len(payload)), self.assertRaises(ValueError):
                read_api('/actions/runs/123', None)
        redirect = Response(b'{}')
        redirect.status = 302
        opener.return_value = redirect
        with self.assertRaises(ValueError):
            read_api('/actions/runs/123', None)
        self.assertIsNone(NoRedirect().redirect_request(None, None, 302, '', {}, 'https://evil.test'))
        opener.side_effect = HTTPError('https://example.test/?secret', 403, 'denied', {}, None)
        with self.assertRaises(ValueError) as raised:
            read_api('/actions/runs/123', 'ghs_dummy')
        self.assertNotIn('ghs_dummy', str(raised.exception))
        self.assertNotIn('secret', str(raised.exception))

    @patch('tools.product_map.release.github_api.read_api')
    def test_fetches_run_and_artifact_metadata_but_not_release_proof(self, read):
        run, artifacts = fixture()
        read.side_effect = [run, artifacts]
        result = fetch_candidate('windows', 123, 'windows-v1.0.52', 'ghs_dummy')
        self.assertEqual(result['status'], 'CANDIDATE_UNVERIFIED')
        self.assertEqual(result['published'], 'UNKNOWN')
        self.assertEqual(read.call_args_list[1].args[0], '/actions/runs/123/artifacts')
        with self.assertRaises(ValueError):
            fetch_candidate('windows', True, 'windows-v1.0.52', None)
