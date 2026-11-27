"""Assess independently observed RTP, never connection labels alone."""


def _advances(before, after):
    return (after.get('inbound_audio_tracks', 0) > 0
            and after.get('inbound_audio_packets', 0) > before.get('inbound_audio_packets', 0)
            and after.get('inbound_audio_bytes', 0) > before.get('inbound_audio_bytes', 0))


def _healthy(row):
    return (row.get('active_peer_connections') == 1
            and row.get('connected_peer_connections') == 1
            and row.get('inbound_audio_tracks', 0) > 0)


def assess_fault(fault, samples):
    if not all(fault.get(key) is True for key in ('pause_verified', 'restore_verified', 'probe_blocked')):
        raise ValueError('Silent dependency fault was not independently verified')
    start = fault['pause_verified_unix_ms']
    end = fault['restore_requested_unix_ms']
    restored = fault['restore_verified_unix_ms']
    if not start < end <= restored or fault['role'] not in ('api', 'sfu'):
        raise ValueError('Invalid fault timeline')
    rows = sorted(samples, key=lambda row: row['observed_at_unix_ms'])
    during = [row for row in rows if start <= row['observed_at_unix_ms'] <= end]
    if len(during) < 4:
        raise ValueError('Insufficient in-fault RTP samples')
    if (during[0]['observed_at_unix_ms']-start > 3000
            or end-during[-1]['observed_at_unix_ms'] > 3000
            or any(b['observed_at_unix_ms']-a['observed_at_unix_ms'] > 6000
                   for a, b in zip(during, during[1:]))):
        raise ValueError('Insufficient in-fault sample coverage')
    if fault['role'] == 'api':
        if any(not _healthy(row) for row in during):
            raise ValueError('Healthy media peer was lost during app fault')
        last_progress = during[0]['observed_at_unix_ms']
        max_stall = 0
        for before, after in zip(during, during[1:]):
            if _advances(before, after):
                last_progress = after['observed_at_unix_ms']
            max_stall = max(max_stall, after['observed_at_unix_ms'] - last_progress)
        packets = during[-1]['inbound_audio_packets'] - during[0]['inbound_audio_packets']
        if packets <= 0 or max_stall > 6000:
            raise ValueError('Media stalled during a verified app-only fault')
        return {'status': 'PASS_SCOPED', 'role': 'api', 'samples_during_fault': len(during),
                'packets_during_fault': packets, 'max_observed_stall_ms': max_stall}
    if not any(row['observed_at_unix_ms'] < start and _healthy(row)
               and row.get('inbound_audio_packets', 0) > 0 for row in rows):
        raise ValueError('No working pre-fault media baseline')
    settled = [row for row in during if row['observed_at_unix_ms'] >= start+3000]
    if len(settled) < 2 or any(_advances(a, b) for a, b in zip(settled, settled[1:])):
        raise ValueError('Paused SFU did not interrupt media after the settle window')
    for before, after in zip(rows, rows[1:]):
        at = after['observed_at_unix_ms']
        if at >= restored and _healthy(after) and _advances(before, after):
            seconds = (at-restored)/1000
            if seconds <= 15:
                return {'status': 'PASS_SCOPED', 'role': 'sfu',
                        'observed_recovery_seconds': seconds, 'samples_during_fault': len(during)}
            break
    raise ValueError('Media did not satisfy the 15-second post-restore target')
