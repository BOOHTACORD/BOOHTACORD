import 'package:boohtacord_desktop/src/features/voice/background_playback/policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active audible voice sessions use playback foreground coverage', () {
    expect(
      shouldKeepVoicePlaybackForeground(
        isAndroid: true,
        voiceActive: true,
        deafened: false,
      ),
      isTrue,
    );
  });

  test('playback foreground coverage is Android-only', () {
    expect(
      shouldKeepVoicePlaybackForeground(
        isAndroid: false,
        voiceActive: true,
        deafened: false,
      ),
      isFalse,
    );
  });

  test('playback foreground stops after leave or deafen', () {
    expect(
      shouldKeepVoicePlaybackForeground(
        isAndroid: true,
        voiceActive: false,
        deafened: false,
      ),
      isFalse,
    );
    expect(
      shouldKeepVoicePlaybackForeground(
        isAndroid: true,
        voiceActive: true,
        deafened: true,
      ),
      isFalse,
    );
  });
}
