/// QA consumer of the existing bounded native aggregate bridge. No frame I/O.
Map<String, Object?> sanitizeCaptureSnapshot(Map<dynamic, dynamic> raw) {
  if (raw['schema_version'] != 1)
    return {
      'schema_version': 1,
      'status': 'unavailable',
      'reason': 'native_bridge_missing_or_unknown_schema',
      'accepted_frames': null,
    };
  const numeric = {
    'generation',
    'configured_width',
    'configured_height',
    'configured_max_fps',
    'source_width',
    'source_height',
    'source_pixel_format',
    'actual_width',
    'actual_height',
    'actual_pixel_format',
    'rotation',
    'accepted_frames',
    'postprocessed_frames',
    'dropped_frames',
    'last_valid_frame_monotonic_ns',
    'frame_age_ms',
    'processing_sample_count',
    'processing_p50_ms',
    'processing_p95_ms',
    'queue_depth','peak_queue_depth','in_flight','peak_in_flight',
    'queue_age_ms','maximum_queue_age_ms','native_resize_frames','i420_scale_frames',
    'buffer_pool_creations','buffer_pool_acquisitions','pool_buffers_first_seen',
    'processing_failures','pass_through_frames','heap_allocations','capture_timestamp_latency_ms',
  };
  const values = {
    'status': {'pending', 'active', 'stopped', 'error', 'unavailable'},
    'engine': {'rtc_desktop_capturer', 'screen_capture_kit'},
    'source_class': {'window', 'display'},
    'error_reason': {
      'start_failed',
      'source_missing',
      'permission_denied',
      'stream_stopped',
      'first_frame_timeout',
      'configuration_failed',
    },
    'frame_age_basis': {'native_monotonic_since_latest_accepted_callback'},
  };
  final result = <String, Object?>{'schema_version': 1};
  for (final key in numeric) {
    final value = raw[key];
    result[key] = value is num && value.isFinite && value >= 0 ? value : null;
  }
  for (final entry in values.entries) {
    final value = raw[entry.key];
    result[entry.key] = entry.value.contains(value) ? value : null;
  }
  result['config_confirmed'] = raw['config_confirmed'] == true;
  final drops = raw['drop_reasons'];
  result['drop_reasons'] = {
    for (final key in [
      'idle',
      'incomplete',
      'invalid',
      'timestamp',
      'stale',
      'processing',
      'queue',
    ])
      if (drops is Map &&
          drops[key] is num &&
          (drops[key] as num).isFinite &&
          (drops[key] as num) >= 0)
        key: drops[key],
  };
  return result;
}
