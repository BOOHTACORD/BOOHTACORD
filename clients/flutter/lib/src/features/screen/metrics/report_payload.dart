import 'sender_report.dart';

const screenSenderReportMaxAgeMs = 15000.0;

Map<String, Object> buildScreenSenderReportPayload({
  required ScreenShareSenderReport report,
  required Map<String, Object> measurementFields,
  required double? sampledAtMs,
  required double nowMs,
}) {
  final context = Map<String, Object>.fromEntries(
    measurementFields.entries.where(
      (entry) => const {
        'target_resolution',
        'target_fps',
        'connection_quality',
      }.contains(entry.key),
    ),
  );
  final age = sampledAtMs == null ? null : nowMs - sampledAtMs;
  if (age == null || !age.isFinite || age < 0) {
    return _fallback(report.platform, 'unavailable', context);
  }
  if (age > screenSenderReportMaxAgeMs) {
    return _fallback(report.platform, 'stale', context);
  }
  return {
    ...report.toJson(),
    ...measurementFields,
    'sample_age_ms': age.round(),
  };
}

Map<String, Object> _fallback(
  String platform,
  String collectionState,
  Map<String, Object> context,
) => {
  'platform': platform,
  'direction': 'sender',
  'state': 'waiting_first_frame',
  ...context,
  'stats_source': 'unsupported',
  'collection_state': collectionState,
};
