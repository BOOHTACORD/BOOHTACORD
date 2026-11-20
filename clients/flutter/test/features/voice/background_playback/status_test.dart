import 'package:boohtacord_desktop/src/features/voice/background_playback/status.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports when Android cannot keep voice playback in background', () {
    expect(
      voicePlaybackWorkspaceStatus(
        VoicePhase.listener,
        backgroundPlaybackUnavailable: true,
      ),
      'Фоновое воспроизведение недоступно · вернитесь в приложение',
    );
  });

  test('keeps the normal connected status when playback is protected', () {
    expect(
      voicePlaybackWorkspaceStatus(
        VoicePhase.listener,
        backgroundPlaybackUnavailable: false,
      ),
      'Голос подключён',
    );
  });
}
