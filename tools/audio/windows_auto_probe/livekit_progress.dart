import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:livekit_client/livekit_client.dart';

import '../windows_livekit_probe/metrics.dart';
import 'monitor.dart';

Future<AutoSample> readAutoSample(
  NativeNoiseSuppression native,
  Room receiver,
  String engine,
) async {
  await native.refresh();
  final state = native.state;
  final counters = await inboundCounters(receiver);
  return (
    processed: state.processedFrames,
    fallback: state.fallbackFrames,
    packets: counters['receivedPackets']!,
    active:
        state.requestedMode == NoiseSuppressionMode.auto &&
        state.effectiveMode == engine &&
        state.status == 'active',
  );
}
