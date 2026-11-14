import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

extension VoiceMicrophoneDeafen on VoiceController {
  Future<void> toggleDeafen() async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    final room = this.room;
    if (room == null || deafenChanging || voicePhase == VoicePhase.leaving) {
      return;
    }
    final wasDeafened = deafened;
    final wasMicrophoneMuted = microphoneMuted;
    final nextDeafened = !wasDeafened;
    deafenChanging = true;
    error = null;
    if (active(ticket, revision)) notifyListeners();
    try {
      if (nextDeafened) {
        sounds.silence();
        mutedBeforeDeafen = wasMicrophoneMuted;
        if (audioActivationMode == AudioActivationMode.ptt ||
            !microphoneMuted) {
          if (!await applyMicrophoneMuted(true)) {
            throw StateError(
              audioActivationError ?? 'Не удалось выключить микрофон.',
            );
          }
        }
        for (final participant in room.remoteParticipants.values) {
          for (final publication in participant.audioTrackPublications) {
            await publication.disable();
            if (!active(ticket, revision)) return;
          }
        }
        if (!active(ticket, revision)) return;
        deafened = true;
      } else {
        for (final participant in room.remoteParticipants.values) {
          for (final publication in participant.audioTrackPublications) {
            await publication.enable();
            if (!active(ticket, revision)) return;
          }
        }
        final shouldUnmute = audioActivationMode == AudioActivationMode.ptt
            ? microphoneAllowed && pushToTalkPressed
            : microphoneAllowed && !mutedBeforeDeafen;
        if (shouldUnmute && !await applyMicrophoneMuted(false)) {
          throw StateError(
            audioActivationError ?? 'Не удалось включить микрофон.',
          );
        }
        if (!active(ticket, revision)) return;
        deafened = false;
        mutedBeforeDeafen = false;
      }
    } catch (cause) {
      if (!active(ticket, revision)) return;
      if (identical(this.room, room) && voicePhase != VoicePhase.leaving) {
        for (final participant in room.remoteParticipants.values) {
          for (final publication in participant.audioTrackPublications) {
            try {
              if (wasDeafened) {
                await publication.disable();
                if (!active(ticket, revision)) return;
              } else {
                await publication.enable();
                if (!active(ticket, revision)) return;
              }
            } catch (_) {
              if (!active(ticket, revision)) return;
            }
          }
        }
        if (microphoneMuted != wasMicrophoneMuted) {
          await applyMicrophoneMuted(wasMicrophoneMuted);
          if (!active(ticket, revision)) return;
        }
      }
      deafened = wasDeafened;
      error = formatError(cause);
    } finally {
      if (active(ticket, revision)) deafenChanging = false;
      if (active(ticket, revision)) notifyListeners();
    }
  }

  Future<void> deafenRemoteAudio(Room room) async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision)) return;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        await publication.disable();
        if (!active(ticket, revision)) return;
      }
    }
  }
}
