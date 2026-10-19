"""Producer metadata pagination must be complete, bounded and credential-safe."""
import io
import json
import unittest
from unittest.mock import patch
from . import api


class ProducerApiTests(unittest.TestCase):
    def test_bounded_pagination_reads_the_exact_run_and_all_artifacts(self):
        reader = api.Reader('owner/repo', '123', 'private-token')
        pages = [{'total_count': 2, 'artifacts': [{'id': 1}]},
                 {'total_count': 2, 'artifacts': [{'id': 2}]}]
        with patch.object(reader, 'read', side_effect=pages) as read:
            self.assertEqual({'total_count': 2, 'artifacts': [{'id': 1}, {'id': 2}]}, reader.collection('artifacts'))
        self.assertEqual(['artifacts?per_page=100&page=1', 'artifacts?per_page=100&page=2'],
                         [call.args[0] for call in read.call_args_list])

    def test_incomplete_changing_oversized_boolean_or_empty_counts_fail(self):
        cases = [[{'total_count': 2, 'jobs': []}], [{'total_count': True, 'jobs': []}],
                 [{'total_count': 2001, 'jobs': []}], [{'total_count': 0, 'jobs': [{}]}],
                 [{'total_count': 2, 'jobs': [{}]}, {'total_count': 3, 'jobs': [{}]}]]
        for pages in cases:
            with self.subTest(pages=pages), patch.object(api.Reader, 'read', side_effect=pages), self.assertRaises(ValueError):
                api.Reader('owner/repo', '123', 'token').collection('jobs')

    def test_jobs_use_latest_attempt_filter_on_every_page(self):
        reader = api.Reader('owner/repo', '123', 'token')
        with patch.object(reader, 'read', return_value={'total_count': 0, 'jobs': []}) as read:
            reader.collection('jobs')
        read.assert_called_once_with('jobs?filter=latest&per_page=100&page=1')

    def test_json_body_is_bounded_and_http_errors_do_not_disclose_credentials(self):
        reader = api.Reader('owner/repo', '123', 'private-token')
        with patch.object(api, 'urlopen', return_value=io.BytesIO(json.dumps({'id': 123}).encode())) as request:
            self.assertEqual({'id': 123}, reader.read())
        self.assertEqual('https://api.github.com/repos/owner/repo/actions/runs/123', request.call_args.args[0].full_url)
        for response in (b'[' + b'0' * (2 * 1024 * 1024), b'not json', b'[]'):
            with patch.object(api, 'urlopen', return_value=io.BytesIO(response)), self.assertRaises(ValueError):
                reader.read()
        with patch.object(api, 'urlopen', side_effect=OSError('private-token must not leak')):
            with self.assertRaises(ValueError) as error: reader.read()
        self.assertNotIn('private-token', str(error.exception))

    def test_arbitrary_run_repository_or_collection_cannot_change_endpoint(self):
        for repo, run in [('owner/repo/other', '123'), ('owner/repo', '123?token=bad'), ('owner/repo', '0')]:
            with self.assertRaises(ValueError): api.Reader(repo, run, 'token')
        with self.assertRaises(ValueError): api.Reader('owner/repo', '123', 'token').collection('../secrets')
