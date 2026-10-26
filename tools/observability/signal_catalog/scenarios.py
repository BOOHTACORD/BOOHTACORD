"""Diagnostic purpose and explicit limits; no new product capability claims."""
SCENARIOS = [
    ('auth', 'Login/logout/restore, expiry and revoke', 'Auth application events; session-probe operational aggregates; realtime session-revalidation failures. A 401 is not a fabricated authenticated user. Client prelogin batches are not exported.'),
    ('messages', 'TEXT/DM send/edit/delete/reply/read cursor', 'Server route event records acceptance/rejection; client message.send root waits for mounted sender render, retries share flow ID with distinct attempts. Reply/mentions reuse the send route; no content or receiver read receipt.'),
    ('attachments', 'Upload/download admission and storage failures', 'Upload events plus bounded failure/status/latency and filesystem snapshots. No attachment bytes, filenames or local paths.'),
    ('search', 'Channel/DM/archive search', 'Fixed route events/outcomes and aggregate HTTP duration. Search query text and matched message text are never telemetry.'),
    ('social', 'Reactions, pins and mentions', 'Reactions/pins use bounded application events; mentions are part of message send. No per-render or per-recipient trace.'),
    ('admin', 'Topology, account controls and guild settings', 'Fixed admin route events, guild settings/update stages and counters; administrator status does not grant DM telemetry payload access.'),
    ('voice', 'Join/leave/transfer/PTT/reconnect/revoke', 'Lease/credential routes and action/worker stages distinguish connection from actual audibility. PTT/audio state is sampled; do not create a trace for every PTT edge or claim physical audio acceptance.'),
    ('screen', 'Publish/view/first frame/switch/fullscreen/mini and QoE', 'screen.view terminal is actual presented first frame where supported, not HTTP ack. app.media and legacy media samples preserve direction/provenance, age and units. Fullscreen/mini do not imply new media session; unsupported cross-publication correlation remains explicit.'),
    ('presence', 'Audience watch/stop and normal heartbeat/polling', 'Actual server transitions and stop/error traces retained. Successful unscoped polling/heartbeat omitted; full HTTP counts/latency remain independent. No viewer IDs in metric labels.'),
    ('desktop_update', 'Check/download/verify/apply/restart/restore/rollback', 'Bounded desktop.update phase/reason/version/duration_ms legacy span and private server catalog/check metrics. Not an invented app.flow chain or proof that update is installed.'),
    ('telemetry', 'Producer queue, relay, exporters and store visibility', 'Keep queue/dropped/retried/accepted distinct. Relay last_accept is receipt age per platform, not Tempo storage success. Collector/Tempo internal metrics and synthetic stored trace prove later stages independently.'),
    ('database', 'Pool pressure and acquisition failures', 'Native private pool collectors and OTLP incident mirrors expose bounded statistics/outcomes; no SQL/DSN/query text.'),
    ('storage', 'Storage admission, private filesystem capacity and readiness', 'On-demand filesystem snapshots may be absent on collector-only wiring; scheduled storage probe is availability, not capacity or a backup.'),
    ('livekit', 'SFU control transport, roster and aggregate media health', 'Private Ping/control/roster aggregates and optional allowlisted LiveKit scrape. No RTP/RTCP proxy or load/capacity claim.'),
    ('realtime', 'Connection readiness, replay/reconnect and workers', 'Separate WebSocket lifetime from readiness/event delivery. Worker links preserve causality and attempts; no per-message/DM payload logging.'),
    ('usage', 'Installation usage collection health', 'Bounded registrations/daily-active/collection signals are opt-in installation aggregates; compare replicas using max rather than summing duplicate snapshots.'),
]


def scenario(name, path=''):
    if name.startswith(('boohtacord.http.', 'voice_platform_api_request', 'voice_platform_operational_', 'voice_platform_rate_limit_')):
        return 'telemetry'
    value = (name + ' ' + path).lower()
    for words, result in [
        (('telemetry', 'trace_export', 'metric_export', 'observe_incidents'), 'telemetry'),
        (('database', '/pool/'), 'database'),
        (('users.', 'observe_usage'), 'usage'),
        (('screen-viewer', 'screen_viewer', 'presence'), 'presence'),
        (('realtime', 'worker', 'revocation', 'finalization'), 'realtime'),
        (('desktop.update', 'client_update', 'release_catalog'), 'desktop_update'),
        (('media', 'screen'), 'screen'),
        (('livekit', 'room_service', 'roster'), 'livekit'),
        (('storage', 'filesystem'), 'storage'),
        (('attachment', 'upload'), 'attachments'),
        (('search',), 'search'),
        (('reaction', 'pinned', 'unpinned', 'mention'), 'social'),
        (('auth', 'session', 'register'), 'auth'),
        (('voice', 'audio'), 'voice'),
        (('admin', 'guild', 'category', 'channel.created', 'channel.renamed', 'channel.archived', 'channel.moved'), 'admin'),
    ]:
        if any(word in value for word in words):
            return result
    return 'messages'
