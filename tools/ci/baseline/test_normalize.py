import json
import unittest
from .normalize import normalize_run, normalize_job, normalize_artifact
from .changes import components


class NormalizeTests(unittest.TestCase):
    def test_allowlist_never_preserves_event_payload_actor_or_urls(self):
        raw = {'id': 1, 'head_sha': 'a' * 40, 'path': '.github/workflows/ci.yaml',
               'event': 'pull_request', 'head_branch': 'secret', 'actor': {'login': 'private'},
               'display_title': 'private text', 'html_url': 'https://private.example',
               'repository': {'private': True}, 'pull_requests': [{'body': 'private body'}]}
        result = normalize_run(raw)
        self.assertEqual(result['url'], 'https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/1')
        self.assertEqual(result['ref_kind'], 'pull_request')
        for secret in ['secret', 'private', 'body', 'actor']:
            self.assertNotIn(secret, json.dumps(result))

    def test_platform_and_upload_step_without_runner_identity(self):
        result = normalize_job({'id': 2, 'name': 'windows / windows', 'labels': ['windows-latest'],
                                'runner_name': 'private-host', 'steps': [
                                    {'name': 'Retain Windows build as workflow artifact', 'number': 1},
                                    {'name': 'Test app', 'number': 2}]})
        self.assertEqual(result['platform'], 'windows')
        self.assertEqual(result['steps'][0]['kind'], 'artifact_upload')
        self.assertNotIn('private-host', json.dumps(result))
        self.assertEqual(result['cache_state'], 'N/A: not exposed by metadata API')

    def test_artifact_identity_not_user_selected_name(self):
        result = normalize_artifact({'id': 3, 'name': 'private-test-user', 'created_at': 't', 'size_in_bytes': 5})
        self.assertNotIn('private', json.dumps(result))
        self.assertEqual(result['size_in_bytes'], 5)

    def test_missing_git_history_is_unknown_not_docs_only(self):
        result = components('0' * 40, 'pull_request', '.')
        self.assertEqual(result['status'], 'N/A')
        self.assertIsNone(result['gates'])
