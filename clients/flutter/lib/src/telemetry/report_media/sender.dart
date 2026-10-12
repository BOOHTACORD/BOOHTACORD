import 'package:livekit_client/livekit_client.dart';

import 'sender_sample.dart';

import '../../screens/screen_packet_loss.dart';
import '../../features/screen/profile/quality.dart';

class SenderMediaTelemetry {
  final _loss = ScreenPacketLossWindow();
  String? _stream;

  void clear() {
    _loss.clear();
    _stream = null;
  }

  Map<String, Object> fields(
    List<SenderMediaSample> stats,
    ScreenShareQuality target,
    ConnectionQuality quality,
  ) {
    SenderMediaSample? selected;
    for (final item in stats) {
      if (selected == null ||
          (item.frameWidth ?? 0) * (item.frameHeight ?? 0) >
              (selected.frameWidth ?? 0) * (selected.frameHeight ?? 0)) {
        selected = item;
      }
    }
    if (selected?.streamId != _stream) {
      clear();
      _stream = selected?.streamId;
    }
    final loss = _loss.add(
      timestampMs: selected?.timestamp.toDouble() ?? double.nan,
      packetsSent: selected?.packetsSent?.toDouble(),
      packetsLost: selected?.packetsLost?.toDouble(),
    );
    final reason = selected?.qualityLimitationReason;
    return {
      'target_resolution': target.resolution,
      'target_fps': target.frameRate,
      'connection_quality': quality.name.toUpperCase(),
      if (loss != null) ...{
        'packet_loss_percent': loss,
        'packet_loss_window_ms': _loss.durationMs!,
      },
      if (['none', 'cpu', 'bandwidth', 'other'].contains(reason))
        'adaptation_reason': reason!,
    };
  }
}
