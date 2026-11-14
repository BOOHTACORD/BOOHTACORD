import 'dart:math' as math;

typedef AutoSample = ({int processed, int fallback, int packets, bool active});

int probeSeconds(String? value) {
  if (value == null) return 6;
  if (!RegExp(r'^[0-9]{1,4}$').hasMatch(value))
    throw FormatException('duration');
  final seconds = int.parse(value);
  if (seconds < 6 || seconds > 1800) throw RangeError('duration');
  return seconds;
}

Future<Map<String, Object?>> monitorAuto({
  required int seconds,
  required Future<AutoSample> Function() read,
  Future<void> Function(Duration)? pause,
}) async {
  probeSeconds('$seconds');
  pause ??= Future<void>.delayed;
  final first = await read();
  var previous = first, current = first;
  var elapsed = 0, intervals = 0, minFrames = 1 << 30, minPackets = 1 << 30;
  String? failure;
  while (elapsed < seconds) {
    final step = math.min(5, seconds - elapsed);
    await pause(Duration(seconds: step));
    current = await read();
    intervals++;
    final frames = current.processed - previous.processed;
    final packets = current.packets - previous.packets;
    minFrames = math.min(minFrames, frames);
    minPackets = math.min(minPackets, packets);
    elapsed += step;
    if (!current.active)
      failure = 'engine-inactive';
    else if (current.fallback != first.fallback)
      failure = 'fallback-changed';
    else if (frames <= 0 || packets <= 0)
      failure = 'media-progress-stalled';
    if (failure != null) break;
    previous = current;
  }
  return {
    'observedSeconds': elapsed,
    'intervals': intervals,
    'minProcessedDelta': minFrames,
    'minReceivedDelta': minPackets,
    'processedDelta': current.processed - first.processed,
    'fallbackDelta': current.fallback - first.fallback,
    'receivedDelta': current.packets - first.packets,
    if (failure != null) 'failureReason': failure,
    'success': failure == null,
  };
}
