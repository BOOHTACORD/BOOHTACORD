import 'package:flutter/foundation.dart';

export '../features/screen/metrics/models.dart';
export '../features/screen/metrics/sender_report.dart';

String? nativeScreenMetricsPlatform(TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.android => 'android_native',
      TargetPlatform.iOS => 'ios_native',
      TargetPlatform.macOS => 'macos_native',
      TargetPlatform.windows => 'windows_native',
      _ => null,
    };

String? nativeScreenTelemetryPlatform(TargetPlatform platform) {
  final value = nativeScreenMetricsPlatform(platform);
  return value?.replaceFirst('_native', '');
}

// flutter_webrtc forwards RTCStats.timestamp_us without converting its unit.
double webRtcStatsTimestampMs(num timestampUs) => timestampUs / 1000;
