"""Per-instrument bounded OTel attributes, reviewed against Add/Record/Observe."""


def otel_labels(name):
    if name.startswith('boohtacord.http.server.'):
        return ['http.request.method', 'http.route', 'http.response.status_code']
    if name.startswith('boohtacord.incident.operational.'):
        return ['method', 'operation', 'status']
    if name.startswith('boohtacord.incident.http.'):
        return ['method', 'route', 'status']
    if name.startswith('boohtacord.telemetry.relay.'):
        suffix = name.removeprefix('boohtacord.telemetry.relay.')
        return {'last_accept': ['platform'], 'records': ['outcome', 'reason', 'platform'],
                'requests': ['http.response.status_code', 'platform'], 'duration': ['http.response.status_code', 'platform']}[suffix]
    if name.startswith('boohtacord.incident.database.'):
        suffix = name.removeprefix('boohtacord.incident.database.')
        return {'pool': ['stat'], 'pool.events': ['stat'], 'pool.empty.acquire.wait': [],
                'acquires.pending': [], 'acquires': ['outcome'], 'acquire.duration': ['outcome']}[suffix]
    if name.startswith('boohtacord.incident.'):
        suffix = name.removeprefix('boohtacord.incident.')
        if suffix in ('operations', 'operation.duration'):
            return ['operation', 'outcome']
        if suffix in ('api.collection.timestamp',):
            return []
        if suffix == 'livekit.snapshot':
            return ['stat']
        return ['operation']
    if name.startswith('boohtacord.users.'):
        return ['period'] if name.endswith(('.registrations', '.daily_active')) else []
    if name.startswith('boohtacord.telemetry.'):
        return ['service_version'] if name.endswith('.build.info') else []
    if name in ('voice_platform_guild_settings_updates', 'voice_platform_registration_welcome'):
        return ['outcome']
    if name.startswith('boohtacord_media_'):
        base = ['platform', 'direction', 'source']
        suffix = name.removeprefix('boohtacord_media_')
        if suffix.startswith(('report_received_', 'sample_age_seconds', 'sample_age_known', 'sample_age_at_receipt_')):
            return base
        if suffix == 'reports':
            return base + ['state', 'freshness']
        if suffix == 'field_reports':
            return base + ['field', 'availability', 'stage', 'role']
        if suffix == 'sample_age_milliseconds':
            return base + ['state']
        result = base + ['state', 'age_provenance']
        if suffix in ('fps', 'fps_target_ratio'):
            result += ['stage']
        if suffix == 'resolution_pixels':
            result += ['role']
        if suffix == 'connection_quality_reports':
            result += ['quality']
        if suffix == 'adaptation_reports':
            result += ['reason']
        return result
    if name.startswith('voice_platform_'):
        if 'transport_failures' in name:
            return ['method', 'class']
        if 'http_failures' in name:
            return ['method', 'status_class']
        if name in ('voice_platform_sfu_room_service_seconds', 'voice_platform_sfu_room_service_calls_total'):
            return ['method', 'outcome']
        if name in ('voice_platform_sfu_room_service_last_attempt_timestamp_seconds', 'voice_platform_sfu_room_service_last_success_timestamp_seconds'):
            return ['method']
        if name in ('voice_platform_voice_presence_gate_total', 'voice_platform_voice_roster_initial_total', 'voice_platform_voice_roster_snapshots_total'):
            return ['outcome']
        if name == 'voice_platform_voice_roster_stream_ends_total':
            return ['reason']
        if name == 'voice_platform_voice_roster_failures_total':
            return ['stage']
        return []
    raise ValueError('new OTel label contract requires review: ' + name)
