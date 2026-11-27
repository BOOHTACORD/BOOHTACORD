import unittest

from tools.qa.client_lifecycle.background_fault.assessment import assess_fault


def sample(at, packets):
    return {'observed_at_unix_ms': at, 'inbound_audio_packets': packets,
            'inbound_audio_bytes': packets*100, 'inbound_audio_tracks': 1,
            'active_peer_connections': 1, 'connected_peer_connections': 1}


def fault(role):
    return {'role': role, 'pause_verified': True, 'restore_verified': True,
            'probe_blocked': True, 'pause_verified_unix_ms': 1000,
            'restore_requested_unix_ms': 12000, 'restore_verified_unix_ms': 12100}


class AssessmentTest(unittest.TestCase):
    def test_app_fault_requires_progress_throughout_the_silent_interval(self):
        rows = [sample(t, t//100) for t in range(0, 16000, 2000)]
        result = assess_fault(fault('api'), rows)
        self.assertEqual(result['status'], 'PASS_SCOPED')
        self.assertGreater(result['packets_during_fault'], 0)
        self.assertLessEqual(result['max_observed_stall_ms'], 6000)

    def test_connected_status_without_media_cannot_pass_api_fault(self):
        rows = [sample(t, 20) for t in range(0, 16000, 2000)]
        with self.assertRaisesRegex(ValueError, 'stalled'):
            assess_fault(fault('api'), rows)

    def test_media_fault_requires_pause_then_observed_recovery_within_target(self):
        rows = [sample(t, 20) for t in range(0, 13000, 2000)]
        rows += [sample(14000, 24), sample(16000, 28)]
        result = assess_fault(fault('sfu'), rows)
        self.assertEqual(result['status'], 'PASS_SCOPED')
        self.assertAlmostEqual(result['observed_recovery_seconds'], 1.9)

    def test_late_or_absent_media_recovery_fails(self):
        for rows in ([sample(t, 20) for t in range(0, 30000, 2000)],
                     [sample(t, 20) for t in range(0, 29000, 2000)]+[sample(30000, 24)]):
            with self.subTest(rows=len(rows)), self.assertRaisesRegex(ValueError, '15-second'):
                assess_fault(fault('sfu'), rows)

    def test_media_fault_that_never_interrupted_packets_is_rejected(self):
        rows = [sample(t, 10+t//100) for t in range(0, 16000, 2000)]
        with self.assertRaisesRegex(ValueError, 'not interrupt'):
            assess_fault(fault('sfu'), rows)

    def test_missing_observations_cannot_claim_continuity(self):
        rows = [sample(t, t//100) for t in (0, 2000, 3000, 10000, 12000, 14000)]
        with self.assertRaisesRegex(ValueError, 'coverage'):
            assess_fault(fault('api'), rows)

    def test_sfu_recovery_without_a_working_prefault_stream_is_rejected(self):
        rows = [sample(t, 20) for t in range(2000, 13000, 2000)]
        rows += [sample(14000, 24)]
        with self.assertRaisesRegex(ValueError, 'pre-fault'):
            assess_fault(fault('sfu'), rows)

    def test_unverified_fault_sparse_samples_or_duplicate_peers_cannot_pass(self):
        rows = [sample(t, t//100) for t in range(0, 16000, 2000)]
        bad = fault('api'); bad['pause_verified'] = False
        with self.assertRaises(ValueError): assess_fault(bad, rows)
        with self.assertRaises(ValueError): assess_fault(fault('api'), rows[:1])
        for row in rows: row['active_peer_connections'] = 2
        with self.assertRaisesRegex(ValueError, 'peer'):
            assess_fault(fault('api'), rows)
