import unittest

from tools.ci.preflight.review import decision


class ReviewTest(unittest.TestCase):
    def setUp(self):
        self.report = {'fingerprint': 'abc', 'diff_check': 'PASS',
                       'unexpected_or_sensitive_paths': [],
                       'generated_checks': {'map': {'status': 'PASS'}},
                       'selection': {'gates': ['contracts']},
                       'actual_acceptance': {'profiles': []},
                       'dependency_review': 'Review all applicable manifest/lockfile pairs.'}
        self.review = {'fingerprint': 'abc', 'checks': {
            key: {'status': 'PASS', 'command': 'checked', 'reason': 'reviewed'}
            for key in ('Contracts', 'Traceability', 'Evidence', 'Generated',
                        'Dependencies', 'Client checks', 'gate:contracts')}}

    def test_complete_manual_attestation_can_allow_commit(self):
        self.assertEqual(decision(self.report, self.review), 'COMMIT_ALLOWED')

    def test_stale_missing_or_failed_inputs_block(self):
        self.review['fingerprint'] = 'old'
        self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')
        self.review['fingerprint'] = 'abc'
        del self.review['checks']['gate:contracts']
        self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')

    def test_selected_gates_and_generated_check_cannot_be_skipped(self):
        self.review['checks']['gate:contracts']['status'] = 'N/A'
        self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')
        self.review['checks']['gate:contracts']['status'] = 'PASS'
        self.report['generated_checks']['map']['status'] = 'BLOCKED'
        self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')

    def test_workspace_change_during_check_blocks(self):
        self.report['scope_changed_during_check'] = True
        self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')

    def test_unresolved_companion_evidence_or_missing_commands_block(self):
        for category in ('Contracts', 'Traceability', 'Evidence', 'Generated', 'Dependencies', 'Client checks'):
            with self.subTest(category=category):
                original = self.review['checks'][category]
                self.review['checks'][category] = {'status': 'BLOCKED', 'reason': 'missing companion'}
                self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')
                self.review['checks'][category] = {'status': 'PASS', 'reason': 'unverified'}
                self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')
                self.review['checks'][category] = original

    def test_na_needs_reason_but_no_irrelevant_evidence_record(self):
        self.review['checks']['Evidence'] = {'status': 'N/A', 'reason': 'no integration or release gate'}
        self.assertEqual(decision(self.report, self.review), 'COMMIT_ALLOWED')
        self.review['checks']['Evidence']['reason'] = ''
        self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')

    def test_explained_hosted_ci_wait_is_not_a_pass(self):
        self.review['checks']['gate:contracts'] = {
            'status': 'BLOCKED', 'reason': 'awaiting PR CI', 'command': 'CI / contracts', 'scope': 'hosted_ci'}
        self.assertEqual(decision(self.report, self.review), 'COMMIT_ALLOWED')
        self.review['checks']['gate:contracts']['scope'] = 'local'
        self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')

    def test_invalid_client_registry_cannot_be_attested_away(self):
        self.report['client_registry_check'] = {'status': 'FAIL'}
        self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')
        self.report['client_registry_check'] = {'status': 'BLOCKED', 'unknown_paths': []}
        self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')

    def test_failed_or_unavailable_native_related_check_blocks(self):
        for status in ('FAIL', 'BLOCKED'):
            self.report['related_checks'] = {'contracts': {'status': status}}
            self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')

    def test_partial_staging_requires_explicit_companion_review(self):
        self.report['inventory'] = {'staged': ['contracts/api.json'], 'unstaged': ['backend/consumer.go'], 'untracked': []}
        self.assertEqual(decision(self.report, self.review), 'COMMIT_BLOCKED')
        self.review['checks']['Staging'] = {'status': 'PASS', 'command': 'git diff --cached; git diff',
                                             'reason': 'Reviewed staged and unstaged companion scope.'}
        self.assertEqual(decision(self.report, self.review), 'COMMIT_ALLOWED')


if __name__ == '__main__':
    unittest.main()
