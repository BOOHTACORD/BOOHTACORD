import 'dart:math' as math;
import 'dart:typed_data';

// Original BOOHTACORD cues, CC0. Same PCM design as Web sound_playback/pcm.ts.
Uint8List defaultSound(String kind) {
  final notes = {
    'joined': [660, 880],
    'left': [660, 440],
    'started': [440, 660, 880],
    'stopped': [880, 660, 440],
  }[kind]!;
  final length = notes.length * 2400,
      result = Uint8List(44 + notes.length * 4800);
  final data = ByteData.sublistView(result);
  void text(int offset, String value) {
    result.setAll(offset, value.codeUnits);
  }

  text(0, 'RIFF');
  data.setUint32(4, result.length - 8, Endian.little);
  text(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 24000, Endian.little);
  data.setUint32(28, 48000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, length * 2, Endian.little);
  for (var i = 0; i < length; i++) {
    final n = i % 2400,
        envelope = math.min(math.min(n / 240, (2400 - n) / 480), 1);
    final sample =
        6000 * envelope * math.sin(2 * math.pi * notes[i ~/ 2400] * n / 24000);
    final quantized = (sample * 1e6 + .5).floor() / 1e6;
    data.setInt16(44 + i * 2, (quantized + .5).floor(), Endian.little);
  }
  return result;
}
