import 'voice_room_event_sounds.dart';

class VoiceParticipantSoundTracker {
  VoiceParticipantSoundTracker(this.play);

  final void Function(VoiceRoomEventSound event) play;
  final Set<String> _participants = <String>{};
  bool _active = false;

  void seed(Iterable<String> identities) {
    _participants
      ..clear()
      ..addAll(identities.where(_isHumanVoiceParticipant));
    _active = true;
  }

  void pause() {
    _active = false;
  }

  void reset() {
    _active = false;
    _participants.clear();
  }

  void participantConnected(String identity) {
    if (!_active ||
        !_isHumanVoiceParticipant(identity) ||
        !_participants.add(identity)) {
      return;
    }
    play(VoiceRoomEventSound.participantJoined);
  }

  void participantDisconnected(String identity) {
    if (!_active || !_isHumanVoiceParticipant(identity)) return;
    if (!_participants.remove(identity)) return;
    play(VoiceRoomEventSound.participantLeft);
  }

  bool _isHumanVoiceParticipant(String identity) =>
      identity.isNotEmpty && !identity.startsWith('voice-lease:');
}
