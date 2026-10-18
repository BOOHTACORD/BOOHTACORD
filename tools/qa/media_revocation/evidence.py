"""Fail-closed receipt validation for the seven POC-03 actions."""
from datetime import datetime

CASES = ('kick', 'ban', 'logout', 'session_revoke', 'password_reset', 'transfer', 'close')
FIELDS = {'case', 'status', 'decoded_frames', 'audio_packets', 'presenter_disconnected',
          'observer_track_removed', 'worker_confirmed', 'observer_connected',
          'refreshed_sdk_credential', 'api_replay_status', 'sdk_replay_status',
          'api_control_status', 'sdk_control_status',
          'credentials_unexpired', 'old_credential_status', 'revoke_delay_ms', 'worker_attempts',
          'action_at', 'action_status', 'prior_session_status', 'observer_lease_status'}


def validate(report):
    rows=report.get('rows', [])
    if report.get('status') != 'PASS' or len(rows) != len(CASES) or {r.get('case') for r in rows} != set(CASES):
        raise ValueError('All seven fresh successful media cases are required')
    for row in rows:
        if set(row) != FIELDS or row['status'] != 'PASS':
            raise ValueError('Only complete sanitized observations may be published')
        if any(row[key] is not True for key in ('presenter_disconnected', 'observer_track_removed',
               'worker_confirmed', 'refreshed_sdk_credential', 'credentials_unexpired')):
            raise ValueError('Media, worker and credential provenance must be observed')
        if row['observer_connected'] is not (row['case'] != 'close'):
            raise ValueError('Unrelated observer must survive every individual revoke')
        expected_action={'logout':204,'session_revoke':204,'password_reset':204,'transfer':201}.get(row['case'],200)
        expected_session=401 if row['case'] in ('ban','logout','session_revoke','password_reset') else 200
        if row['action_status'] != expected_action or row['prior_session_status'] != expected_session or row['observer_lease_status'] != (409 if row['case']=='close' else 200):
            raise ValueError('Authoritative mutation, prior session and observer lease must match the case')
        try:
            parsed=datetime.fromisoformat(row['action_at'].replace('Z','+00:00'))
            if parsed.tzinfo is None: raise ValueError('UTC observation required')
        except (TypeError,AttributeError,ValueError) as error:
            raise ValueError('Missing actual observation time') from error
        if any(type(row[key]) is not int or row[key] <= 0 for key in ('decoded_frames', 'audio_packets', 'worker_attempts')):
            raise ValueError('Actual received media and dispatch attempt required')
        if row['api_replay_status'] != 403 or row['sdk_replay_status'] != 403 or row['old_credential_status'] not in (401,403,404,409):
            raise ValueError('Both unexpired credentials and old lease issuance must be denied')
        if row['api_control_status'] != 101 or row['sdk_control_status'] != 101:
            raise ValueError('Identical handshake probes must succeed before authoritative revoke')
        if type(row['revoke_delay_ms']) not in (int,float) or not 0 <= row['revoke_delay_ms'] <= 45000:
            raise ValueError('Missing or unbounded actual revoke time')
    return report
