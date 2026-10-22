import unittest

from tools.qa.telemetry_delivery.probe_metrics import private_origin, verify_series


class MetricsDeliveryTest(unittest.TestCase):
    def test_fixture_cannot_target_public_or_authenticated_origins(self):
        for value in ('https://example.com', 'http://example.com', 'http://127.0.0.1.evil.test', 'http://a:b@127.0.0.1', 'http://127.0.0.1/private'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                private_origin(value)
        self.assertEqual(private_origin('http://127.0.0.1:4318/'), 'http://127.0.0.1:4318')

    def test_required_sample_and_privacy_are_not_replaced_by_empty_success(self):
        with self.assertRaises(AssertionError):
            verify_series([])
        row = {'metric': {'__name__': 'boohtacord_qa_delivery_latency_seconds_sum', 'service_name': 'boohtacord-qa-delivery'}, 'value': [1, '.25']}
        verify_series([row])
        for label in ('user_id', 'session_id', 'app_visit_id', 'app_flow_id', 'app_media_session_id', 'trace_id', 'user.id', 'app.visit.id'):
            with self.subTest(label=label), self.assertRaises(AssertionError):
                verify_series([{**row, 'metric': {**row['metric'], label: 'synthetic'}}])


if __name__ == '__main__':
    unittest.main()
