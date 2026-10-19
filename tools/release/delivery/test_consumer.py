"""A protected current controller may install an older exact signed source."""
import unittest
from . import consumer

REPO = 'Egkurilov/BOOHTACORD'
SHA = 'a' * 40
SOURCE = 'b' * 40


def fixtures(mode='automatic'):
    automatic = mode == 'automatic'
    workflow = 'deploy-production.yaml' if automatic else 'install-retained-release.yaml'
    env = {'GITHUB_ACTIONS': 'true', 'RUNNER_OS': 'Linux', 'GITHUB_REPOSITORY': REPO,
           'GITHUB_REF': 'refs/heads/master', 'GITHUB_SHA': SHA,
           'GITHUB_WORKFLOW_REF': REPO + '/.github/workflows/' + workflow + '@refs/heads/master',
           'GITHUB_EVENT_NAME': 'workflow_run' if automatic else 'workflow_dispatch',
           'DELIVERY_MODE': mode, 'BUILD_RUN_ID': '123', 'REQUESTED_REVISION': '' if automatic else SOURCE}
    event = {'repository': {'full_name': REPO}, 'workflow_run': {
        'id': 123, 'head_sha': SOURCE, 'head_repository': {'full_name': REPO},
        'head_branch': 'master', 'path': '.github/workflows/build-server.yaml',
        'event': 'push', 'status': 'completed', 'conclusion': 'success'}} if automatic else {
            'repository': {'full_name': REPO}, 'inputs': {'build_run_id': '123', 'revision': SOURCE}}
    return env, event


class ControllerAuthorityTests(unittest.TestCase):
    def test_automatic_and_retained_keep_controller_distinct_from_artifact_source(self):
        for mode in ('automatic', 'retained'):
            env, event = fixtures(mode)
            self.assertEqual(SHA, consumer.validate(env, event, SHA))

    def test_foreign_branch_pr_wrong_controller_or_mode_is_rejected(self):
        for field, value in [('GITHUB_ACTIONS', 'false'), ('RUNNER_OS', 'Windows'),
                             ('GITHUB_REPOSITORY', 'fork/repo'), ('GITHUB_REF', 'refs/heads/codex/change'),
                             ('GITHUB_SHA', SOURCE), ('GITHUB_EVENT_NAME', 'pull_request'),
                             ('GITHUB_WORKFLOW_REF', REPO + '/.github/workflows/ci.yaml@refs/heads/master'),
                             ('DELIVERY_MODE', 'unknown'), ('BUILD_RUN_ID', '00123')]:
            env, event = fixtures(); env[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): consumer.validate(env, event, SHA)

    def test_automatic_inputs_cannot_replace_the_event_producer(self):
        for mutation in ('id', 'source', 'failed', 'fork', 'requested', 'repository'):
            env, event = fixtures()
            if mutation == 'id': event['workflow_run']['id'] = 124
            if mutation == 'source': event['workflow_run']['head_sha'] = 'short'
            if mutation == 'failed': event['workflow_run']['conclusion'] = 'failure'
            if mutation == 'fork': event['workflow_run']['head_repository']['full_name'] = 'fork/repo'
            if mutation == 'requested': env['REQUESTED_REVISION'] = SOURCE
            if mutation == 'repository': event['repository']['full_name'] = 'fork/repo'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): consumer.validate(env, event, SHA)

    def test_retained_inputs_must_equal_the_dispatch_and_have_exact_revision(self):
        for field, value in [('build_run_id', '124'), ('revision', SHA), ('revision', '')]:
            env, event = fixtures('retained'); event['inputs'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError): consumer.validate(env, event, SHA)
        env, event = fixtures('retained'); env['REQUESTED_REVISION'] = event['inputs']['revision'] = 'short'
        with self.assertRaises(ValueError): consumer.validate(env, event, SHA)

    def test_incomplete_event_or_non_string_controller_is_fail_closed(self):
        env, event = fixtures()
        for invalid in (None, [], {}, {'repository': None}, {'repository': {'full_name': REPO}}):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError): consumer.validate(env, invalid, SHA)
        for invalid in (None, True, 'short'):
            with self.assertRaises(ValueError): consumer.validate(env, event, invalid)
