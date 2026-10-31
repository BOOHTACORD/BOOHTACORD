import 'dart:async';

import 'package:flutter/services.dart';

enum VoiceRoomEventSound {
  participantJoined,
  participantLeft,
  streamViewStarted,
  streamViewStopped,
}

SystemSoundType systemSoundForVoiceRoomEvent(VoiceRoomEventSound event) =>
    switch (event) {
      VoiceRoomEventSound.participantJoined ||
      VoiceRoomEventSound.streamViewStarted => SystemSoundType.click,
      VoiceRoomEventSound.participantLeft ||
      VoiceRoomEventSound.streamViewStopped => SystemSoundType.alert,
    };

void playVoiceRoomEventSound({
  required bool enabled,
  required VoiceRoomEventSound event,
}) {
  if (!enabled) return;
  unawaited(
    SystemSound.play(systemSoundForVoiceRoomEvent(event))
        .catchError((Object _) {}),
  );
}
