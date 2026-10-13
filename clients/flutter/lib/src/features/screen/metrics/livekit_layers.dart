import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../../../services/screen_share_metrics.dart';
import 'counter_window.dart';
import 'layers.dart';

class ScreenSenderLayerSource {
  const ScreenSenderLayerSource(this.counters, this.roundTripTimeSeconds);

  final ScreenSenderLayerCounters counters;
  final double? roundTripTimeSeconds;
  int? get width => screenCounterPixelDimension(counters.width);
  int? get height => screenCounterPixelDimension(counters.height);
}

class LiveKitScreenLayerSample {
  const LiveKitScreenLayerSample(this.diagnostics, this.sources, this.selected);
  final ScreenSenderLayerSample diagnostics;
  final List<ScreenSenderLayerSource> sources;
  final ScreenSenderLayerSource? selected;
}

num? _number(rtc.StatsReport row, String name) {
  final value = row.values[name];
  return value is num && value.isFinite ? value : null;
}

String? _text(rtc.StatsReport row, String name) {
  final value = row.values[name];
  return value is String && value.isNotEmpty ? value : null;
}

String? _encoderImplementation(rtc.StatsReport row) {
  // A closed SDK label projection prevents unbounded strings reaching exports.
  // A label such as VideoToolbox alone does not prove hardware acceleration.
  const allowed = {
    'libvpx',
    'libvpx VP8',
    'libvpx VP9',
    'VideoToolbox',
    'AppleVideoToolbox',
    'ExternalEncoder',
    'OpenH264',
    'libaom',
    'SimulcastEncoderAdapter',
    'SimulcastEncoderAdapter (libvpx)',
    'SimulcastEncoderAdapter (VideoToolbox)',
    'unknown',
  };
  final label = _text(row, 'encoderImplementation');
  return allowed.contains(label) ? label : null;
}

List<ScreenSenderLayerSource> screenSenderSourcesFromReports(
  List<rtc.StatsReport> reports,
) {
  final codecs = {
    for (final row in reports.where((row) => row.type == 'codec'))
      row.id: _text(row, 'mimeType'),
  };
  final remotes = {
    for (final row in reports.where((row) => row.type == 'remote-inbound-rtp'))
      row.id: row,
  };
  return reports
      .where(
        (row) =>
            row.type == 'outbound-rtp' &&
            (_text(row, 'kind') ?? _text(row, 'mediaType') ?? 'video') ==
                'video',
      )
      .take(8)
      .map((row) {
        final remoteId = _text(row, 'remoteId');
        final candidate = remoteId == null ? null : remotes[remoteId];
        final remote =
            candidate != null &&
                (_text(candidate, 'localId') == null ||
                    _text(candidate, 'localId') == row.id) &&
                (_number(candidate, 'ssrc') == null ||
                    _number(candidate, 'ssrc') == _number(row, 'ssrc'))
            ? candidate
            : null;
        final codecId = _text(row, 'codecId');
        final counters = ScreenSenderLayerCounters(
          streamId: row.id,
          transport: screenSenderTransportFromReports(row, reports),
          ssrc: _number(row, 'ssrc'),
          rid: _text(row, 'rid'),
          codec: codecId == null ? null : codecs[codecId],
          timestampMs: webRtcStatsTimestampMs(row.timestamp),
          width: _number(row, 'frameWidth'),
          height: _number(row, 'frameHeight'),
          encodedFrames: _number(row, 'framesEncoded'),
          qpSum: _number(row, 'qpSum'),
          encoderImplementation: _encoderImplementation(row),
          powerEfficientEncoder: row.values['powerEfficientEncoder'] is bool
              ? row.values['powerEfficientEncoder'] as bool
              : null,
          framesSent: _number(row, 'framesSent'),
          active: row.values['active'] is bool
              ? row.values['active'] as bool
              : null,
          totalEncodeTime: _number(row, 'totalEncodeTime'),
          retransmittedBytes: _number(row, 'retransmittedBytesSent'),
          bytesSent: _number(row, 'bytesSent'),
          packetsSent: _number(row, 'packetsSent'),
          packetsLost: remote == null ? null : _number(remote, 'packetsLost'),
          retransmittedPackets: _number(row, 'retransmittedPacketsSent'),
          nackCount: _number(row, 'nackCount'),
          pliCount: _number(row, 'pliCount'),
          firCount: _number(row, 'firCount'),
          qualityLimitationReason: _text(row, 'qualityLimitationReason'),
          qualityLimitationDurations: _durations(
            row.values['qualityLimitationDurations'],
          ),
        );
        final rtt = remote == null
            ? null
            : _number(remote, 'roundTripTime')?.toDouble();
        return ScreenSenderLayerSource(counters, rtt);
      })
      .toList(growable: false);
}

LiveKitScreenLayerSample sampleLiveKitScreenLayers(
  ScreenSenderLayerSampler sampler,
  List<ScreenSenderLayerSource> sources,
  double receivedAtMs,
) {
  final diagnostics = sampler.sample(
    sources.map((source) => source.counters).toList(growable: false),
    receivedAtMs,
  );
  final id = diagnostics.selected?.id;
  ScreenSenderLayerSource? selected;
  if (id != null) {
    for (final source in sources) {
      if (source.counters.id == id) {
        selected = source;
        break;
      }
    }
  }
  return LiveKitScreenLayerSample(diagnostics, sources, selected);
}

Map<String, double>? _durations(Object? raw) {
  if (raw is! Map) return null;
  return {
    for (final key in ['none', 'cpu', 'bandwidth', 'other'])
      if (raw[key] is num &&
          (raw[key] as num).isFinite &&
          (raw[key] as num) >= 0)
        key: (raw[key] as num).toDouble(),
  };
}
