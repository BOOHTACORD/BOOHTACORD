import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';
import '../../../services/voice_connection_quality.dart';
import '../../../services/voice_reconnect_policy.dart';

extension VoiceEventsConnection on VoiceController {
  void bindConnection(
    Room room,
    EventsListener<RoomEvent> listener,
    bool Function() owns,
  ) {
    listener.on<ParticipantConnectionQualityUpdatedEvent>((event) {
      if (!owns()) return;
      if (disconnect.notice != null) return;
      if (!identical(this.room, room) && voicePhase != VoicePhase.joining) {
        return;
      }
      if (!identical(event.participant, room.localParticipant)) return;
      notifyListeners();
    });
    listener.on<AudioSenderStatsEvent>((event) {
      if (!owns()) return;
      if (disconnect.notice != null) return;
      if (!identical(this.room, room) && voicePhase != VoicePhase.joining) {
        return;
      }
      final ping = voiceRttMilliseconds(event.stats.roundTripTime);
      if (ping == null) return;
      if (voicePingMs == ping) return;
      voicePingMs = ping;
      notifyListeners();
    });
    listener.on<RoomAttemptReconnectEvent>((event) {
      if (!owns()) return;
      if (!identical(this.room, room) ||
          voicePhase != VoicePhase.reconnecting ||
          shouldAllowVoiceReconnectAttempt(event.attempt)) {
        return;
      }
      if (leaseId != null) disconnect.bind(leaseId!, voiceChannel?.id ?? '');
      disconnect.transport(
        'Не удалось восстановить голосовое соединение после $voiceReconnectAttemptLimit попыток. Подключитесь ещё раз.',
      );
      showVoiceDisconnect();
      unawaited(leaveVoice(explicit: false));
    });
    listener.on<RoomReconnectingEvent>((_) {
      if (!owns()) return;
      if (disconnect.notice != null) return;
      if (!identical(this.room, room) && voicePhase != VoicePhase.joining) {
        return;
      }
      voicePhase = VoicePhase.reconnecting;
      voiceParticipantSoundTracker.pause();
      stopVoiceConnectionStatsPolling();
      voicePingMs = null;
      observeVoiceStreamStarts(room);
      notifyListeners();
    });
    listener.on<RoomResumingEvent>((_) {
      if (!owns()) return;
      if (disconnect.notice != null) return;
      if (!identical(this.room, room) && voicePhase != VoicePhase.joining) {
        return;
      }
      voicePhase = VoicePhase.reconnecting;
      voiceParticipantSoundTracker.pause();
      stopVoiceConnectionStatsPolling();
      voicePingMs = null;
      observeVoiceStreamStarts(room);
      notifyListeners();
    });
    listener.on<RoomReconnectedEvent>((_) {
      if (!owns() || disconnect.notice != null) return;
      if (!identical(this.room, room)) return;
      voicePhase = listenerOnly ? VoicePhase.listener : VoicePhase.connected;
      voiceParticipantSoundTracker.seed(
        room.remoteParticipants.values.map(
          (participant) => participant.identity,
        ),
      );
      startVoiceConnectionStatsPolling(room);
      observeVoiceStreamStarts(room);
      subscribeCurrentRemoteVoiceTracks(room);
      final selectedIdentity = selectedRemoteScreenViewerIdentity;
      if (selectedIdentity != null) {
        subscribeRemoteScreenForViewing(room, selectedIdentity);
      }
      unawaited(applySavedVoiceVolumes(room));
      if (deafened) unawaited(deafenRemoteAudio(room));
      if (audioActivationMode == AudioActivationMode.ptt) {
        if (pushToTalkPressed && !deafened) {
          listenerOnly = false;
          voicePhase = VoicePhase.connected;
        }
        unawaited(applyMicrophoneMuted(!pushToTalkPressed || deafened));
      }
      notifyListeners();
    });
    listener.on<RoomDisconnectedEvent>((event) {
      if (!owns()) return;
      voiceParticipantSoundTracker.reset();
      if (!identical(this.room, room) || voicePhase == VoicePhase.leaving) {
        return;
      }
      unawaited(handleUnexpectedVoiceDisconnect(room, event));
    });
  }
}
