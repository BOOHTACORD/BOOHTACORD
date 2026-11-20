import 'dart:async';

import '../lifecycle/controller.dart';
import 'policy.dart';

extension VoiceBackgroundPlayback on VoiceController {
  Future<bool> syncVoicePlaybackForeground() async {
    final keep = shouldKeepVoicePlaybackForeground(
      isAndroid: voicePlaybackForeground.isAndroid,
      voiceActive: room != null && voicePhase != VoicePhase.leaving,
      deafened: deafened,
    );
    if (!keep) {
      await voicePlaybackForeground.stop();
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
    if (!await voicePlaybackForeground.canStart()) {
      voicePlaybackBackgroundUnavailable = true;
      notifyListeners();
      return false;
    }
    final started = await voicePlaybackForeground.start();
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
