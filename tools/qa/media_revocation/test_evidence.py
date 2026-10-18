"""Incomplete media or replay observations must never close POC-03."""
import copy
import unittest
from .evidence import CASES, validate


def complete():
    rows = []
    for name in CASES:
        rows.append(dict(case=name, status='PASS', decoded_frames=3,
                         audio_packets=3, presenter_disconnected=True,
                         observer_track_removed=True, worker_confirmed=True,
                         observer_connected=name != 'close',
                         refreshed_sdk_credential=True,
                         api_replay_status=403, sdk_replay_status=403,
                         api_control_status=101, sdk_control_status=101,
                         credentials_unexpired=True, old_credential_status=409,
                         revoke_delay_ms=100, worker_attempts=1,
                         action_at='2026-10-18T08:00:00.000Z',
                         action_status={'logout':204,'session_revoke':204,'password_reset':204,'transfer':201}.get(name,200),
                         prior_session_status=401 if name in ('ban','logout','session_revoke','password_reset') else 200,
                         observer_lease_status=409 if name=='close' else 200))
    return dict(status='PASS', rows=rows)


class EvidenceTests(unittest.TestCase):
    def test_all_seven_real_media_rows_required(self):
        self.assertEqual(validate(complete())['status'], 'PASS')
        for key, value in [('decoded_frames', 0), ('audio_packets', 0),
                           ('presenter_disconnected', False), ('observer_track_removed', False),
                           ('worker_confirmed', False), ('refreshed_sdk_credential', False),
                           ('credentials_unexpired', False), ('api_replay_status', 101),
                           ('sdk_replay_status', 401), ('old_credential_status', 200),
                           ('api_control_status',400), ('sdk_control_status',403),
                           ('action_at','unobserved'), ('action_status',500),
                           ('observer_lease_status',409), ('prior_session_status',401)]:
            with self.subTest(key=key):
                report = complete(); report['rows'][0][key] = value
                with self.assertRaises(ValueError): validate(report)
        report=complete(); report['rows'].pop()
        with self.assertRaises(ValueError): validate(report)

    def test_duplicates_and_unobserved_results_cannot_replace_cases(self):
        report=complete(); report['rows'][-1]=copy.deepcopy(report['rows'][0])
        with self.assertRaises(ValueError): validate(report)
        for state in ('FAIL', 'NOT_RUN', 'BLOCKED'):
            report=complete(); report['rows'][-1]['status']=state
            with self.assertRaises(ValueError): validate(report)

    def test_only_channel_close_may_disconnect_observer(self):
        report=complete(); report['rows'][0]['observer_connected']=False
        with self.assertRaises(ValueError): validate(report)

    def test_unknown_fields_cannot_publish_credentials(self):
        for field in ('token', 'cookie', 'url', 'account_id', 'error'):
            report=complete(); report['rows'][0][field]='private'
            with self.assertRaises(ValueError): validate(report)
