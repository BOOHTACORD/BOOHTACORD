import 'counter_window.dart';
import 'models.dart';

export 'models.dart';

class _PreviousScreenSenderLayer {
  const _PreviousScreenSenderLayer(this.counters, this.receivedAtMs);
  final ScreenSenderLayerCounters counters;
  final double receivedAtMs;
}

class ScreenSenderLayerSampler {
  static const _maximumAgeMs = 10000.0;
  Map<String, _PreviousScreenSenderLayer> _previous = {};
  void clear() => _previous = {};

  ScreenSenderLayerSample sample(
    List<ScreenSenderLayerCounters> rows,
    double receivedAtMs,
  ) {
    final next = <String, _PreviousScreenSenderLayer>{};
    final layers = <ScreenSenderLayerMetrics>[];
    for (final row in rows.take(8)) {
      final id = row.id;
      final prior = _previous[id];
      final previous = prior?.counters;
      final elapsed = previous == null
          ? 0.0
          : row.timestampMs - previous.timestampMs;
      final gap = prior == null ? 0.0 : receivedAtMs - prior.receivedAtMs;
      final stale =
          prior != null &&
          (!gap.isFinite || gap > _maximumAgeMs || elapsed > _maximumAgeMs);
      final validStamp = row.timestampMs.isFinite && row.timestampMs >= 0;
      final validWindow =
          validStamp &&
          prior != null &&
          gap > 0 &&
          gap <= _maximumAgeMs &&
          elapsed > 0 &&
          elapsed <= _maximumAgeMs;
      final reset =
          validWindow &&
          screenCounterReset([
            (row.framesSent, previous?.framesSent),
            (row.encodedFrames, previous?.encodedFrames),
            (row.bytesSent, previous?.bytesSent),
            (row.packetsSent, previous?.packetsSent),
            (row.retransmittedPackets, previous?.retransmittedPackets),
            (row.nackCount, previous?.nackCount),
            (row.pliCount, previous?.pliCount),
            (row.firCount, previous?.firCount),
          ]);
      final interval =
          validWindow &&
          !reset &&
          row.active != false &&
          previous?.active != false;
      double? delta(num? current, num? before) {
        if (!interval ||
            current == null ||
            before == null ||
            !screenCounterValid(current) ||
            !screenCounterValid(before) ||
            current < before) {
          return null;
        }
        return current.toDouble() - before.toDouble();
      }

      final frames = delta(row.framesSent, previous?.framesSent);
      final bytes = delta(row.bytesSent, previous?.bytesSent);
      final sent = delta(row.packetsSent, previous?.packetsSent);
      final lost = delta(row.packetsLost, previous?.packetsLost);
      final repeated = delta(
        row.retransmittedPackets,
        previous?.retransmittedPackets,
      );
      final nacks = delta(row.nackCount, previous?.nackCount);
      final plis = delta(row.pliCount, previous?.pliCount);
      final firs = delta(row.firCount, previous?.firCount);
      final encoded = delta(row.encodedFrames, previous?.encodedFrames);
      final qp = delta(row.qpSum, previous?.qpSum);
      final averageQp = encoded != null && encoded > 0 && qp != null
          ? qp / encoded
          : null;
      final encode = delta(row.totalEncodeTime, previous?.totalEncodeTime);
      final retransmittedBytes = delta(
        row.retransmittedBytes,
        previous?.retransmittedBytes,
      );
      final primaryFrames = row.encodedFrames != null ? encoded : frames;
      final state = stale
          ? 'STALE'
          : row.active == false
          ? 'INACTIVE'
          : reset
          ? 'UNKNOWN'
          : primaryFrames != null
          ? primaryFrames > 0
                ? 'ACTIVE'
                : 'INACTIVE'
          : 'UNKNOWN';
      double? rate(double? value, double multiplier) =>
          state == 'ACTIVE' && interval && value != null
          ? value * multiplier / gap
          : null;
      int? dimension(num? value) => screenCounterPixelDimension(value);
      layers.add(
        ScreenSenderLayerMetrics(
          frameCounterSource: row.frameCounterSource,
          timestampMs: row.timestampMs,
          id: id,
          rid: row.rid,
          codec: row.codec,
          state: state,
          width: dimension(row.width),
          height: dimension(row.height),
          windowMs: interval ? gap : null,
          framesPerSecond: rate(primaryFrames, 1000),
          encodedFramesPerSecond: interval && encoded != null
              ? encoded * 1000 / gap
              : null,
          sentFramesPerSecond: interval && frames != null
              ? frames * 1000 / gap
              : null,
          bitrateBps: interval && bytes != null ? bytes * 8000 / gap : null,
          encodeMsPerFrame:
              interval && encoded != null && encoded > 0 && encode != null
              ? encode * 1000 / encoded
              : null,
          retransmittedBps: rate(retransmittedBytes, 8000),
          retransmittedPacketsPerSecond: rate(repeated, 1000),
          packetLossPercent:
              state == 'ACTIVE' &&
                  sent != null &&
                  lost != null &&
                  sent > 0 &&
                  lost <= sent
              ? lost * 100 / sent
              : null,
          nackPerSecond: rate(nacks, 1000),
          pliPerSecond: rate(plis, 1000),
          firPerSecond: rate(firs, 1000),
          qualityLimitationReason: row.qualityLimitationReason,
          transport: row.transport,
          encoderImplementation: row.encoderImplementation,
          powerEfficientEncoder: row.powerEfficientEncoder,
          averageQp: averageQp != null && averageQp <= 255 ? averageQp : null,
        ),
      );
      if (validStamp && receivedAtMs.isFinite && receivedAtMs >= 0) {
        next[id] = previous?.timestampMs == row.timestampMs
            ? prior!
            : _PreviousScreenSenderLayer(row, receivedAtMs);
      }
    }
    _previous = next;
    final active = layers.where((layer) => layer.state == 'ACTIVE').toList()
      ..sort(
        (a, b) =>
            (b.width ?? 0) * (b.height ?? 0) - (a.width ?? 0) * (a.height ?? 0),
      );
    return ScreenSenderLayerSample(
      List.unmodifiable(layers),
      active.isEmpty ? null : active.first,
    );
  }
}
