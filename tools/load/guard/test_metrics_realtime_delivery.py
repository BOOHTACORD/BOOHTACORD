import unittest
from tools.load.guard.metrics import aggregate


class RealtimeDeliveryMetricsTest(unittest.TestCase):
    def test_fixed_histogram_buckets_only(self):
        metrics = aggregate("""voice_platform_realtime_event_delivery_seconds_bucket{le="0.025"} 7
voice_platform_realtime_event_delivery_seconds_bucket{le="0.05"} 10
voice_platform_realtime_event_delivery_seconds_bucket{le="0.05",account="secret"} 99
voice_platform_realtime_event_delivery_seconds_bucket{le="unbounded"} 12
voice_platform_realtime_event_delivery_seconds_sum 0.3
voice_platform_realtime_event_delivery_seconds_count 10
voice_platform_realtime_event_stage_seconds_bucket{stage="handler",le="0.025"} 6
voice_platform_realtime_event_stage_seconds_bucket{stage="before_handler",le="0.025"} 8
voice_platform_realtime_event_stage_seconds_bucket{stage="handler",le="0.025",account="secret"} 99
voice_platform_realtime_event_stage_seconds_count{stage="handler"} 10
voice_platform_realtime_session_revalidation_seconds_count 42
voice_platform_realtime_session_revalidation_seconds_sum 0.8
""")
        self.assertEqual(metrics['voice_platform_realtime_event_delivery_seconds_bucket.le.0.025'], 7)
        self.assertEqual(metrics['voice_platform_realtime_event_delivery_seconds_bucket.le.0.05'], 10)
        self.assertEqual(metrics['voice_platform_realtime_event_delivery_seconds_count'], 10)
        self.assertEqual(metrics['voice_platform_realtime_event_delivery_seconds_sum'], 0.3)
        self.assertEqual(metrics['voice_platform_realtime_session_revalidation_seconds_count'], 42)
        self.assertEqual(metrics['voice_platform_realtime_session_revalidation_seconds_sum'], 0.8)
        self.assertEqual(metrics['voice_platform_realtime_event_stage_seconds.handler.bucket.0.025'], 6)
        self.assertEqual(metrics['voice_platform_realtime_event_stage_seconds.before_handler.bucket.0.025'], 8)
        self.assertEqual(metrics['voice_platform_realtime_event_stage_seconds.handler.count'], 10)
        self.assertNotIn('secret', repr(metrics))
        self.assertNotIn('unbounded', repr(metrics))


if __name__ == '__main__':
    unittest.main()
