import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/voice_room_event_sounds.dart';

void main() {
  test('maps room events to concise system feedback', () {
    expect(
      systemSoundForVoiceRoomEvent(VoiceRoomEventSound.participantJoined),
      SystemSoundType.click,
    );
    expect(
      systemSoundForVoiceRoomEvent(VoiceRoomEventSound.participantLeft),
      SystemSoundType.alert,
    );
    expect(
      systemSoundForVoiceRoomEvent(VoiceRoomEventSound.streamViewStarted),
      SystemSoundType.click,
    );
    expect(
      systemSoundForVoiceRoomEvent(VoiceRoomEventSound.streamViewStopped),
      SystemSoundType.alert,
    );
  });
}
