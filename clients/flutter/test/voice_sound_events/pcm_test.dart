import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_playback/pcm.dart';

void main() {
  test('matches the shared Web PCM catalog for all four cues', () {
    final fixtures = jsonDecode(
      File('../../contracts/voice-sound-pcm.fixtures.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final entry in fixtures.entries) {
      expect(sha256.convert(defaultSound(entry.key)).toString(), entry.value);
    }
  });
}
