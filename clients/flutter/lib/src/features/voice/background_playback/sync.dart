import 'dart:async';

import '../lifecycle/controller.dart';
import 'policy.dart';

extension VoiceBackgroundPlayback on VoiceController {
  Future<bool> syncVoicePlaybackForeground() async {
    final targetRoom = room;
    final request = voicePlaybackForeground.beginSynchronization();
    bool current() =>
        !disposed &&
        identical(room, targetRoom) &&
        voicePlaybackForeground.isSynchronizationCurrent(request);
    final keep = shouldKeepVoicePlaybackForeground(
      isAndroid: voicePlaybackForeground.isAndroid,
      voiceActive: room != null && voicePhase != VoicePhase.leaving,
      deafened: deafened,
    );
    if (!keep) {
      await voicePlaybackForeground.stop();
      if (!current()) return false;
      if (voicePlaybackBackgroundUnavailable) {
        voicePlaybackBackgroundUnavailable = false;
        notifyListeners();
      }
      return true;
    }
    if (voicePlaybackForeground.active) {
      if (voicePlaybackBackgroundUnavailable) {
        voicePlaybackBackgroundUnavailable = false;
        notifyListeners();
      }
      return true;
    }
    final permitted = await voicePlaybackForeground.canStart();
    if (!current()) return false;
    if (!permitted) {
      voicePlaybackBackgroundUnavailable = true;
      notifyListeners();
      return false;
    }
    final started = await voicePlaybackForeground.start();
    if (!current()) return false;
    final stillNeeded = shouldKeepVoicePlaybackForeground(
      isAndroid: voicePlaybackForeground.isAndroid,
      voiceActive: room != null && voicePhase != VoicePhase.leaving,
      deafened: deafened,
    );
    if (!stillNeeded) {
      await voicePlaybackForeground.stop();
      return false;
    }
    voicePlaybackBackgroundUnavailable = !started;
    notifyListeners();
    return started;
  }

  void backgroundPlaybackStopped() {
    if (disposed ||
        room == null ||
        deafened ||
        voicePhase == VoicePhase.leaving) {
      return;
    }
    voicePlaybackForeground.active = false;
    voicePlaybackBackgroundUnavailable = true;
    notifyListeners();
  }

  void stopVoicePlaybackForeground() {
    unawaited(voicePlaybackForeground.stop());
  }
}
