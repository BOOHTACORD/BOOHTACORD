"""Private snapshots: fixed metric names only, no labels or unbounded samples."""
import math
import re
import urllib.request
from .roster_ws_metrics import roster_counter
from .realtime_delivery_metrics import delivery_metric, stage_metric

ALLOWED = frozenset(('go_goroutines', 'go_memstats_alloc_bytes', 'go_gc_duration_seconds_sum',
    'go_gc_duration_seconds_count', 'process_cpu_seconds_total', 'process_resident_memory_bytes',
    'voice_platform_api_requests_total', 'voice_platform_api_request_duration_seconds_sum',
    'voice_platform_api_request_duration_seconds_count', 'voice_platform_database_acquire_duration_seconds_sum',
    'voice_platform_database_acquire_duration_seconds_count', 'voice_platform_database_pool_acquired', 'voice_platform_database_pool_idle',
    'voice_platform_database_pool_total', 'voice_platform_database_pool_max',
    'voice_platform_database_acquires_pending', 'voice_platform_database_pool_empty_acquire_wait_seconds_total',
    'voice_platform_database_acquires_total', 'voice_platform_realtime_connections_active',
    'voice_platform_realtime_connections_total', 'voice_platform_realtime_session_revalidation_seconds_count',
    'voice_platform_realtime_session_revalidation_seconds_sum', 'voice_platform_realtime_connection_ready_seconds_sum',
    'voice_platform_realtime_connection_ready_seconds_count', 'voice_platform_attachment_upload_reserved_bytes',
    'voice_platform_attachment_filesystem_available_bytes', 'voice_platform_attachment_filesystem_snapshot_success',
    'voice_platform_upload_failures_total', 'voice_platform_voice_participants_active',
    'voice_platform_voice_streams_active', 'voice_platform_voice_screen_streams_active',
    'voice_platform_voice_media_snapshot_success', 'voice_platform_voice_roster_ws_subscribers',
    'voice_platform_voice_roster_ws_delivery_seconds_count',
    'voice_platform_voice_roster_ws_last_success_timestamp_seconds',
    'voice_platform_voice_roster_ws_observation_enabled'))


def aggregate(text):
    result = {}
    for line in text.splitlines():
        delivery = delivery_metric(line) or stage_metric(line)
        if delivery is not None:
            result[delivery[0]] = delivery[1]
        roster = roster_counter(line)
        if roster is not None:
            result[roster[0]] = roster[1]
        maintenance = re.fullmatch(r'voice_platform_maintenance_observer_reads_total\{outcome="(success|failure)"\} ([0-9.eE+\-]+)', line)
        if maintenance and math.isfinite(float(maintenance[2])):
            result['voice_platform_maintenance_observer_reads_total.outcome.'+maintenance[1]] = float(maintenance[2])
        scoped = re.fullmatch(r'voice_platform_realtime_connections_active\{scope="(public|authenticated)"\} ([0-9.eE+\-]+)', line)
        if scoped and math.isfinite(float(scoped[2])):
            result['voice_platform_realtime_connections_active.scope.'+scoped[1]] = float(scoped[2])
        match = re.fullmatch(r'([a-zA-Z_:][a-zA-Z0-9_:]*)(?:\{[^\n]*\})? ([0-9.eE+\-]+)', line)
        if match and match[1] in ALLOWED:
            value = float(match[2])
            if math.isfinite(value):
                result[match[1]] = result.get(match[1], 0)+value
    return result


def snapshot():
    with urllib.request.urlopen('http://127.0.0.1:4820/metrics', timeout=2) as response:
        return aggregate(response.read(2 << 20).decode())
