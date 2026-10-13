import 'counter_window.dart';
import 'transport_snapshot.dart';
export 'transport_snapshot.dart';

class ScreenSenderLayerCounters {
  const ScreenSenderLayerCounters({
    required this.streamId,
    required this.rid,
    required this.codec,
    this.ssrc,
    required this.timestampMs,
    required this.width,
    required this.height,
    required this.framesSent,
    required this.bytesSent,
    required this.packetsSent,
    required this.packetsLost,
    required this.retransmittedPackets,
    this.nackCount,
    this.pliCount,
    this.firCount,
    this.encodedFrames,
    this.qpSum,
    this.encoderImplementation,
    this.powerEfficientEncoder,
    this.qualityLimitationDurations,
    this.active,
    this.totalEncodeTime,
    this.retransmittedBytes,
    this.qualityLimitationReason,
    this.transport,
  });
  final ScreenSenderTransportSnapshot? transport;
  final String streamId;
  final num? ssrc;
  final String? rid;
  final String? codec;
  final double timestampMs;
  final num? width, height, framesSent, bytesSent, packetsSent, packetsLost;
  final num? retransmittedPackets, encodedFrames, qpSum;
  final String? encoderImplementation;

  /// RTC-reported efficiency flag; it does not verify hardware encoder selection.
  final bool? powerEfficientEncoder;
  String get frameCounterSource => encodedFrames != null
      ? 'encoded'
      : framesSent != null
      ? 'sent'
      : 'unsupported';
  final num? nackCount, pliCount, firCount, totalEncodeTime, retransmittedBytes;
  final bool? active;
  final Map<String, double>? qualityLimitationDurations;
  final String? qualityLimitationReason;

  String get id => '$streamId:${ssrc ?? ''}:${rid ?? ''}';
}

class ScreenSenderLayerMetrics {
  const ScreenSenderLayerMetrics({
    required this.id,
    required this.rid,
    required this.codec,
    required this.state,
    required this.width,
    required this.height,
    required this.framesPerSecond,
    required this.bitrateBps,
    required this.retransmittedPacketsPerSecond,
    required this.packetLossPercent,
    required this.nackPerSecond,
    required this.pliPerSecond,
    required this.firPerSecond,
    this.frameCounterSource = 'unsupported',
    this.timestampMs,
    this.windowMs,
    this.encodeMsPerFrame,
    this.retransmittedBps,
    this.encodedFramesPerSecond,
    this.sentFramesPerSecond,
    this.averageQp,
    this.encoderImplementation,
    this.powerEfficientEncoder,
    this.transport,
    required this.qualityLimitationReason,
  });
  final ScreenSenderTransportSnapshot? transport;
  final double? averageQp;
  final String? encoderImplementation;

  /// RTC-reported efficiency flag; not a hardware acceptance result.
  final bool? powerEfficientEncoder;
  final String frameCounterSource;
  final double? timestampMs;
  final String id;
  final String? rid, codec;
  final String state;
  final int? width, height;
  final double? framesPerSecond,
      encodedFramesPerSecond,
      sentFramesPerSecond,
      bitrateBps,
      retransmittedPacketsPerSecond;
  final double? packetLossPercent;
  final double? nackPerSecond,
      pliPerSecond,
      firPerSecond,
      windowMs,
      encodeMsPerFrame,
      retransmittedBps;
  final String? qualityLimitationReason;
}

class ScreenSenderLayerSample {
  const ScreenSenderLayerSample(this.layers, this.selected);
  final List<ScreenSenderLayerMetrics> layers;
  final ScreenSenderLayerMetrics? selected;
}

class ScreenShareSenderStats {
  const ScreenShareSenderStats({
    required this.timestampMs,
    this.frameWidth,
    this.frameHeight,
    this.bytesSent,
    this.framesSent,
    this.framesPerSecond,
    this.roundTripTimeSeconds,
  });
  final double timestampMs;
  final num? frameWidth, frameHeight, bytesSent, framesSent, framesPerSecond;
  final num? roundTripTimeSeconds;
}

class ScreenShareSenderSnapshot {
  const ScreenShareSenderSnapshot({
    required this.timestampMs,
    this.frameWidth,
    this.frameHeight,
    this.bytesSent,
    this.framesSent,
    this.framesPerSecond,
    this.roundTripTimeSeconds,
  });
  final double timestampMs;
  final int? frameWidth, frameHeight;
  final double? bytesSent, framesSent, framesPerSecond, roundTripTimeSeconds;
}

ScreenShareSenderSnapshot? screenShareSenderSnapshotFromStats(
  List<ScreenShareSenderStats> stats,
) {
  if (stats.isEmpty) return null;
  final selected = stats.reduce(
    (best, candidate) =>
        (candidate.frameWidth ?? 0) * (candidate.frameHeight ?? 0) >
            (best.frameWidth ?? 0) * (best.frameHeight ?? 0)
        ? candidate
        : best,
  );
  final bytes = stats
      .map((item) => screenMetricCounter(item.bytesSent))
      .whereType<double>()
      .toList(growable: false);
  final width = screenCounterPixelDimension(selected.frameWidth);
  final height = screenCounterPixelDimension(selected.frameHeight);
  return ScreenShareSenderSnapshot(
    timestampMs: selected.timestampMs,
    frameWidth: width == null || height == null ? null : width,
    frameHeight: width == null || height == null ? null : height,
    bytesSent: bytes.isEmpty ? null : bytes.fold<double>(0, (a, b) => a + b),
    framesSent: screenMetricCounter(selected.framesSent),
    framesPerSecond: screenMetricCounter(selected.framesPerSecond),
    roundTripTimeSeconds: screenMetricCounter(selected.roundTripTimeSeconds),
  );
}
