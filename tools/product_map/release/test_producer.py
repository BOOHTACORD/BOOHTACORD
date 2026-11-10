import copy
import unittest

from tools.product_map.release.producer import select_native_artifact


def fixture():
    sha = 'a' * 40
    repo = {'id': 42, 'full_name': 'BOOHTACORD/BOOHTACORD'}
    run = {'id': 123, 'run_attempt': 2, 'head_sha': sha, 'head_branch': 'windows-v1.0.52',
           'repository': repo, 'head_repository': repo,
           'path': '.github/workflows/windows-release.yaml', 'event': 'push',
           'status': 'completed', 'conclusion': 'success'}
    artifact = {'id': 98, 'name': f'native-release-windows-{sha}-123-2',
                'digest': 'sha256:' + 'b' * 64, 'size_in_bytes': 200, 'expired': False,
                'workflow_run': {'id': 123, 'repository_id': 42, 'head_repository_id': 42,
                                 'head_sha': sha, 'head_branch': 'windows-v1.0.52'}}
    return run, {'total_count': 1, 'artifacts': [artifact]}


class ProducerTests(unittest.TestCase):
    def test_exact_successful_native_artifact_only(self):
        run, artifacts = fixture()
        result = select_native_artifact(run, artifacts, 'windows', 123, 'windows-v1.0.52')
        self.assertEqual(result['artifact_id'], 98)
        self.assertEqual(result['status'], 'CANDIDATE_UNVERIFIED')
        self.assertEqual(result['published'], 'UNKNOWN')
        self.assertEqual((result['platform'], result['tag']), ('windows', 'windows-v1.0.52'))

    def test_bad_workflow_run_and_source_are_rejected(self):
        for key, value in [('path', '.github/workflows/ci.yaml'), ('event', 'pull_request'),
                           ('conclusion', 'failure'), ('head_sha', 'x' * 40),
                           ('head_branch', 'foreign'), ('run_attempt', True)]:
            run, artifacts = fixture()
            run[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                select_native_artifact(run, artifacts, 'windows', 123, 'windows-v1.0.52')

    def test_wrong_attempt_digest_owner_or_duplicate_fail_closed(self):
        for mutation in ('attempt', 'digest', 'owner', 'expired', 'duplicate', 'truncated'):
            run, artifacts = fixture()
            item = artifacts['artifacts'][0]
            if mutation == 'attempt': item['name'] = item['name'][:-1] + '1'
            if mutation == 'digest': item['digest'] = None
            if mutation == 'owner': item['workflow_run']['head_repository_id'] = 43
            if mutation == 'expired': item['expired'] = True
            if mutation == 'duplicate': artifacts['artifacts'].append(copy.deepcopy(item)); artifacts['total_count'] = 2
            if mutation == 'truncated': artifacts['total_count'] = 2
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                select_native_artifact(run, artifacts, 'windows', 123, 'windows-v1.0.52')
