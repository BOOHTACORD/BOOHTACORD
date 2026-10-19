"""Retained bundles belong to one trusted source, producer and exact attempt."""
import copy
import unittest
from . import producer_artifacts

REPO = 'owner/repo'
SHA = 'a' * 40


def fixtures(modern=True, attempt=2):
    run = {'id': 123, 'run_attempt': attempt, 'head_sha': SHA, 'head_branch': 'master',
           'repository': {'id': 9, 'full_name': REPO}, 'head_repository': {'id': 9, 'full_name': REPO},
           'path': '.github/workflows/build-server.yaml', 'event': 'push',
           'status': 'completed', 'conclusion': 'success'}
    artifact = {'id': 44, 'name': f'server-{SHA}' + (f'-123-{attempt}' if modern else ''),
                'size_in_bytes': 100, 'digest': 'sha256:' + 'b' * 64, 'expired': False,
                'workflow_run': {'id': 123, 'repository_id': 9, 'head_repository_id': 9,
                                 'head_sha': SHA, 'head_branch': 'master'}}
    return run, {'total_count': 1, 'artifacts': [artifact]}


class ProducerArtifactTests(unittest.TestCase):
    def test_exact_current_execution_name_and_ownership_are_required(self):
        run, document = fixtures()
        value = producer_artifacts.select(123, run, document, REPO, True)
        self.assertEqual((44, f'server-{SHA}-123-2', 2, SHA),
                         (value['id'], value['name'], value['run_attempt'], value['source_revision']))

    def test_old_attempt_is_retained_but_cannot_replace_current_attempt(self):
        run, document = fixtures(); old = copy.deepcopy(document['artifacts'][0])
        old.update(id=45, name=f'server-{SHA}-123-1', expired=True)
        document['artifacts'].append(old); document['total_count'] = 2
        self.assertEqual(44, producer_artifacts.select(123, run, document, REPO, True)['id'])
        document['artifacts'].pop(0); document['total_count'] = 1
        with self.assertRaises(ValueError): producer_artifacts.select(123, run, document, REPO, True)

    def test_legacy_signed_bundle_name_remains_readable(self):
        run, document = fixtures(False)
        document['artifacts'][0]['digest'] = None
        self.assertEqual(f'server-{SHA}', producer_artifacts.select(123, run, document, REPO, False)['name'])
        with self.assertRaises(ValueError): producer_artifacts.select(123, run, document, REPO, True)

    def test_same_sha_from_foreign_run_repository_branch_or_source_fails(self):
        for field, value in [('id', 999), ('repository_id', 10), ('head_repository_id', 10),
                             ('head_sha', 'c' * 40), ('head_branch', 'feature')]:
            run, document = fixtures(); document['artifacts'][0]['workflow_run'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                producer_artifacts.select(123, run, document, REPO, True)
        run, document = fixtures()
        with self.assertRaises(ValueError): producer_artifacts.select(999, run, document, REPO, True)

    def test_failed_incomplete_fork_pr_or_wrong_workflow_producer_is_rejected(self):
        for field, value in [('conclusion', 'failure'), ('status', 'in_progress'), ('event', 'pull_request'),
                             ('head_branch', 'feature'), ('path', '.github/workflows/ci.yaml'),
                             ('head_repository', {'id': 10, 'full_name': 'fork/repo'})]:
            run, document = fixtures(); run[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                producer_artifacts.select(123, run, document, REPO, True)

    def test_expired_unmeasured_or_invalid_metadata_is_not_a_bundle(self):
        for field, value in [('expired', True), ('expired', None), ('size_in_bytes', 0),
                             ('size_in_bytes', True), ('digest', None), ('digest', 'wrong'), ('id', True)]:
            run, document = fixtures(); document['artifacts'][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                producer_artifacts.select(123, run, document, REPO, True)

    def test_duplicate_truncated_missing_mixed_or_future_attempt_artifacts_fail(self):
        for mutation in ('duplicate-id', 'duplicate-name', 'truncated', 'missing', 'legacy-mix', 'future'):
            run, document = fixtures(); row = document['artifacts'][0]
            if mutation == 'truncated': document['total_count'] = 2
            elif mutation == 'missing': document.update(total_count=0, artifacts=[])
            else:
                extra = copy.deepcopy(row)
                if mutation != 'duplicate-id': extra['id'] = 45
                if mutation == 'legacy-mix': extra['name'] = f'server-{SHA}'
                if mutation == 'future': extra['name'] = f'server-{SHA}-123-3'
                document['artifacts'].append(extra); document['total_count'] = 2
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                producer_artifacts.select(123, run, document, REPO, True)

    def test_boolean_or_nonpositive_run_attempt_is_not_an_execution_identity(self):
        for value in (True, 0, '2', None):
            run, document = fixtures(); run['run_attempt'] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                producer_artifacts.select(123, run, document, REPO, True)
