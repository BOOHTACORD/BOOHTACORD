import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/voice_participant_sound_tracker.dart';
import 'package:boohtacord_desktop/src/features/voice/voice_room_event_sounds.dart';

void main() {
  test('sounds only for joins and leaves after seeding the initial roster', () {
    final sounds = <VoiceRoomEventSound>[];
    final tracker = VoiceParticipantSoundTracker(sounds.add);

    tracker.seed(['already-here']);
    tracker.participantConnected('already-here');
    tracker.participantConnected('new-member');
    tracker.participantConnected('new-member');
    tracker.participantDisconnected('already-here');
    tracker.participantDisconnected('new-member');
    tracker.participantDisconnected('new-member');

    expect(sounds, [
      VoiceRoomEventSound.participantJoined,
      VoiceRoomEventSound.participantLeft,
      VoiceRoomEventSound.participantLeft,
    ]);
  });

  test(
    'reconnect replaces the baseline without replaying transient events',
    () {
      final sounds = <VoiceRoomEventSound>[];
      final tracker = VoiceParticipantSoundTracker(sounds.add);

      tracker.seed(['member-a']);
      tracker.pause();
      tracker.participantDisconnected('member-a');
      tracker.participantConnected('member-b');
      tracker.seed(['member-b']);
      tracker.participantConnected('member-b');
      tracker.participantConnected('member-c');

      expect(sounds, [VoiceRoomEventSound.participantJoined]);
    },
  );

  test(
    'does not report participant events until connected state is seeded',
    () {
      final sounds = <VoiceRoomEventSound>[];
      final tracker = VoiceParticipantSoundTracker(sounds.add);

      tracker.participantConnected('early-event');
      tracker.seed(['early-event']);
      tracker.reset();
      tracker.participantConnected('after-reset');

      expect(sounds, isEmpty);
    },
  );

  test('ignores server-side screen preview participants', () {
    final sounds = <VoiceRoomEventSound>[];
    final tracker = VoiceParticipantSoundTracker(sounds.add);

    tracker.seed(['voice-lease:screen-preview']);
    tracker.participantConnected('voice-lease:screen-preview');
    tracker.participantDisconnected('voice-lease:screen-preview');

    expect(sounds, isEmpty);
  });
}
