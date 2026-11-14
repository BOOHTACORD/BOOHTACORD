import 'package:boohtacord_desktop/src/services/voice_participant_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('speaking is suppressed when the microphone cannot be heard', () {
    expect(
      VoiceParticipantPresentation.resolve(
        speaking: true,
        muted: true,
      ).isSpeaking,
      isFalse,
    );
    expect(
      VoiceParticipantPresentation.resolve(
        speaking: true,
        microphoneUnavailable: true,
      ).isSpeaking,
      isFalse,
    );
    expect(
      VoiceParticipantPresentation.resolve(
        speaking: true,
        deafened: true,
      ).isSpeaking,
      isFalse,
    );
  });

  test('status priority matches the web participant status', () {
    expect(
      VoiceParticipantPresentation.resolve(
        speaking: true,
        muted: true,
        microphoneUnavailable: true,
        deafened: true,
      ).label,
      'Не слышит участников',
    );
    expect(
      VoiceParticipantPresentation.resolve(
        speaking: true,
        microphoneUnavailable: true,
      ).label,
      'Микрофон недоступен',
    );
    expect(
      VoiceParticipantPresentation.resolve(muted: true).label,
      'Микрофон выключен',
    );
    expect(
      VoiceParticipantPresentation.resolve(speaking: true).label,
      'Говорит',
    );
    expect(VoiceParticipantPresentation.resolve().label, 'В канале');
  });
}
