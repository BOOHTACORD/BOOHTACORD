import unittest
from tools.release.native_contract.tags import prepare


class TagsTest(unittest.TestCase):
    def setUp(self):
        self.sha = 'a' * 40
        self.env = dict(GITHUB_REPOSITORY='BOOHTACORD/BOOHTACORD',
                        GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/master',
                        GITHUB_SHA=self.sha)

    def test_creates_only_the_canonical_tag_at_current_master(self):
        calls = []
        def request(path, method='GET', body=None):
            calls.append((path, method, body))
            return None if len(calls) == 1 else {'object': {'type': 'commit', 'sha': self.sha}}
        result = prepare('macos', self.env, self.sha, self.sha, '1.0.45', request)
        self.assertEqual(result['tag'], 'macos-v1.0.45')
        self.assertEqual(calls[1][2], {'ref': 'refs/tags/macos-v1.0.45', 'sha': self.sha})

    def test_existing_matching_tag_is_read_only_and_foreign_tag_is_rejected(self):
        calls = []
        def request(path, method='GET', body=None):
            calls.append(method)
            return {'object': {'type': 'commit', 'sha': self.sha}}
        prepare('android', self.env, self.sha, self.sha, '1.0.45', request)
        self.assertEqual(calls, ['GET'])
        with self.assertRaises(ValueError):
            prepare('android', self.env, self.sha, self.sha, '1.0.45',
                    lambda *_: {'object': {'type': 'commit', 'sha': 'b' * 40}})

    def test_branch_fork_stale_head_and_unreviewed_platform_fail_before_api(self):
        def request(*_):
            self.fail('No API write/read is allowed for an invalid source')
        for field, value in [('GITHUB_REF', 'refs/heads/feature'),
                             ('GITHUB_REPOSITORY', 'fork/BOOHTACORD'),
                             ('GITHUB_EVENT_NAME', 'pull_request')]:
            with self.assertRaises(ValueError):
                prepare('macos', dict(self.env, **{field: value}), self.sha,
                        self.sha, '1.0.45', request)
        for platform, master in [('linux', self.sha), ('macos', 'b' * 40)]:
            with self.assertRaises(ValueError):
                prepare(platform, self.env, self.sha, master, '1.0.45', request)
