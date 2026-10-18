import unittest
from .report import build_report, delivery_links
from .test_metrics import job, T0, T1, T2


def run(sha, created=T0, end=T1, conclusion='success'):
    return {'id': 1, 'head_sha': sha, 'created_at': created, 'conclusion': conclusion,
            'status': 'completed', 'jobs': [job('bundle', created, end)], 'url': 'url',
            'run_attempt': 1, 'artifacts': [{'id': 2, 'created_at': T1, 'server_source_sha': sha}]}


class ReportTests(unittest.TestCase):
    def test_delivery_match_requires_unique_exact_sha_producer_and_success(self):
        build, deploy = run('a' * 40), run('a' * 40, T1, T2)
        build['jobs'][0]['steps'] = [{'name': 'Retain the exact verified release', 'conclusion': 'success', 'completed_at': T1}]
        links = delivery_links([build], [deploy])
        self.assertEqual(links[0]['artifact_to_install_success_upper_seconds'], 60)
        self.assertEqual(delivery_links([run('b' * 40)], [deploy])[0]['status'], 'N/A')
        self.assertEqual(delivery_links([build, build], [deploy])[0]['status'], 'N/A')
        deploy['conclusion'] = 'failure'
        self.assertEqual(delivery_links([build], [deploy])[0]['status'], 'N/A')

    def test_missing_required_gate_policy_and_cache_never_invent_pass(self):
        report = build_report({'ci_pr': [run('a' * 40)]})
        self.assertIsNone(report['required_green_seconds'])
        self.assertIsNone(report['billing_minutes'])
        self.assertIsNone(report['cache_hit_rate'])

    def test_prior_cancelled_attempt_is_included_in_execution_cost(self):
        r = run('a' * 40, T0, T2)
        r['run_attempt'] = 2
        r['attempts'] = [{'number': 1, 'jobs': [job('a', T0, T1, 'cancelled')]},
                         {'number': 2, 'jobs': [job('b', T1, T2)]}]
        self.assertEqual(build_report({'ci_pr': [r]})['cohorts']['ci_pr']['job_minutes']['p50'], 2)

    def test_unrelated_artifacts_and_missing_upload_cannot_create_delivery_timing(self):
        b, d = run('a' * 40), run('a' * 40, T1, T2)
        self.assertEqual(delivery_links([b], [d])[0]['status'], 'N/A')
        b['jobs'][0]['steps'] = [{'name': 'Retain the exact verified release',
                                 'conclusion': 'success', 'completed_at': T1}]
        b['artifacts'][0]['server_source_sha'] = 'b' * 40
        self.assertEqual(delivery_links([b], [d])[0]['status'], 'N/A')
