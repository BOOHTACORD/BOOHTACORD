import 'dart:convert';

import 'sender_report.dart';

const _maximumSampleAgeMs = 15000.0;
const _maximumEnvelopeBytes = 2048;

class ScreenTelemetryPublicationScope {
  const ScreenTelemetryPublicationScope({
    required this.ownerLeaseId,
    required this.mediaSessionId,
    required this.publicationGeneration,
    this.captureWidth,
    this.captureHeight,
    this.captureFps,
  });

  final String ownerLeaseId;
  final String mediaSessionId;
  final int publicationGeneration;
  final int? captureWidth, captureHeight;
  final num? captureFps;
}

Map<String, Object?> buildFlutterScreenTelemetryEnvelope({
  required ScreenTelemetryPublicationScope scope,
  required String platform,
  required ScreenShareSenderReport report,
  required Map<String, Object> measurementFields,
  required int sequence,
  required double? sampledAtMonotonicMs,
  required double nowMonotonicMs,
}) {
  const platforms = {'android', 'ios', 'macos', 'windows'};
  final age = sampledAtMonotonicMs == null
      ? null
      : nowMonotonicMs - sampledAtMonotonicMs;
  final ageIsValid = age != null && age.isFinite && age >= 0;
  final stale =
      sampledAtMonotonicMs != null &&
      (!ageIsValid || age > _maximumSampleAgeMs);
  final unsupported = measurementFields['stats_source'] == 'unsupported';
  if (!platforms.contains(platform) ||
      !_uuid.hasMatch(scope.ownerLeaseId) ||
      !_mediaSession.hasMatch(scope.mediaSessionId) ||
      scope.publicationGeneration < 1 ||
      sequence < 1 ||
      !nowMonotonicMs.isFinite) {
    throw ArgumentError('Invalid screen telemetry scope.');
  }

  final lossWindow = measurementFields['packet_loss_window_ms'];
  final loss = lossWindow is num && lossWindow >= 9000
      ? measurementFields['packet_loss_percent']
      : null;
  final reason = measurementFields['adaptation_reason'];
  final envelope = <String, Object?>{
    'schema_version': 1,
    'media_session_id': scope.mediaSessionId,
    'publication_generation': scope.publicationGeneration,
    'platform': platform,
    'client_kind': 'flutter',
    'capability_version': 1,
    'sequence': sequence,
    if (ageIsValid && age <= 60000) 'sender_sample_age_ms': age.floor(),
    'capture': {
      'width': _measured(scope.captureWidth, 16384, minimum: 1, integral: true),
      'height': _measured(
        scope.captureHeight,
        16384,
        minimum: 1,
        integral: true,
      ),
      'fps': _configured(scope.captureFps, 240),
    },
    'encode': {
      'fps': _dynamic(report.encodedFps, 240, unsupported, stale),
      'bitrate_bps': _dynamic(
        report.bitrateKbps == null ? null : report.bitrateKbps! * 1000,
        100000000,
        unsupported,
        stale,
      ),
    },
    'transport': {
      'packet_loss_percent': _dynamic(
        loss is num ? loss : null,
        100,
        unsupported,
        stale,
      ),
      'rtt_ms': _dynamic(report.roundTripTimeMs, 60000, unsupported, stale),
      'quality_limitation_reason': _reason(reason, unsupported, stale),
    },
  };
  if (utf8.encode(jsonEncode(envelope)).length > _maximumEnvelopeBytes) {
    throw ArgumentError('Screen telemetry envelope exceeds the payload limit.');
  }
  return envelope;
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _mediaSession = RegExp(r'^[A-Za-z0-9_-]{1,256}$');

Map<String, Object?> _unavailable(String availability) => {
  'availability': availability,
  'provenance': 'unavailable',
};

Map<String, Object?> _measured(
  num? value,
  num maximum, {
  num minimum = 0,
  bool integral = false,
}) {
  if (value == null ||
      !value.isFinite ||
      value < minimum ||
      value > maximum ||
      (integral && value != value.roundToDouble())) {
    return _unavailable('not_exposed');
  }
  return {
    'value': value,
    'availability': 'measured',
    'provenance': 'sender_measured',
  };
}

Map<String, Object?> _configured(num? value, num maximum) {
  if (value == null || !value.isFinite || value < 1 || value > maximum) {
    return _unavailable('not_exposed');
  }
  return {
    'value': value,
    'availability': 'configured_only',
    'provenance': 'configured',
  };
}

Map<String, Object?> _dynamic(
  num? value,
  num maximum,
  bool unsupported,
  bool stale,
) {
  if (stale) return _unavailable('stale');
  if (unsupported) return _unavailable('unsupported');
  return _measured(value, maximum);
}

Map<String, Object?> _reason(Object? value, bool unsupported, bool stale) {
  if (stale) return _unavailable('stale');
  if (unsupported) return _unavailable('unsupported');
  if (value is! String ||
      !const {'none', 'bandwidth', 'cpu', 'encoder'}.contains(value)) {
    return _unavailable('not_exposed');
  }
  return {
    'value': value,
    'availability': 'measured',
    'provenance': 'sender_measured',
  };
}
