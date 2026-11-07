import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

extension VoiceStreamNoticeEvents on VoiceController {
  void observeVoiceStreamStarts(Room room) {
    final connected =
        voicePhase == VoicePhase.connected || voicePhase == VoicePhase.listener;
    final reconnecting = voicePhase == VoicePhase.reconnecting;
    if (!connected && !reconnecting) {
      clearVoiceStreamNotice(resetTracker: true, notify: false);
      return;
    }

    final remoteScreenSharers = room.remoteParticipants.values
        .where(
          (participant) => participant.videoTrackPublications.any(
            (publication) => publication.source == TrackSource.screenShareVideo,
          ),
        )
        .map((participant) => participant.identity);
    final startedBy = voiceStreamStartTracker.observe(
      remoteScreenSharers,
      connected: connected,
      reconnecting: reconnecting,
    );
    if (startedBy == null) return;

    voiceStreamNoticeTimer?.cancel();
    voiceStreamStartNotice = true;
    voiceStreamNoticeTimer = Timer(const Duration(seconds: 6), () {
      voiceStreamNoticeTimer = null;
      voiceStreamStartNotice = false;
      notifyListeners();
    });

  }

  void clearVoiceStreamNotice({
    required bool resetTracker,
    required bool notify,
  }) {
    voiceStreamNoticeTimer?.cancel();
    voiceStreamNoticeTimer = null;
    final changed = voiceStreamStartNotice;
    voiceStreamStartNotice = false;
    if (resetTracker) voiceStreamStartTracker.reset();
    if (notify && changed) notifyListeners();
  }
}
