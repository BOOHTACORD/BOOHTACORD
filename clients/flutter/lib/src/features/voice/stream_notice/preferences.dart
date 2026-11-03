import 'package:shared_preferences/shared_preferences.dart';

import '../lifecycle/controller.dart';

extension VoiceStreamNoticePreferences on VoiceController {
  Future<void> loadVoiceStreamSoundPreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      voiceStreamSoundEnabled =
          preferences.getBool(VoiceController.voiceStreamSoundPreferenceKey) ??
          true;
    } catch (_) {
      // The in-memory default remains enabled when preferences are unavailable.
    }
  }

  Future<void> setVoiceStreamSoundEnabled(bool enabled) async {
    if (voiceStreamSoundEnabled == enabled) return;
    voiceStreamSoundEnabled = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(
        VoiceController.voiceStreamSoundPreferenceKey,
        enabled,
      );
    } catch (_) {
      // Keep the current-session preference even if persistence fails.
    }
  }

  Future<void> loadVoiceRoomEventSoundPreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      voiceRoomEventSoundsEnabled =
          preferences.getBool(
            VoiceController.voiceRoomEventSoundPreferenceKey,
          ) ??
          true;
    } catch (_) {
      // The in-memory default remains enabled when preferences are unavailable.
    }
  }

  Future<void> setVoiceRoomEventSoundsEnabled(bool enabled) async {
    if (voiceRoomEventSoundsEnabled == enabled) return;
    voiceRoomEventSoundsEnabled = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(
        VoiceController.voiceRoomEventSoundPreferenceKey,
        enabled,
      );
    } catch (_) {
      // Keep the current-session preference even if persistence fails.
    }
  }
}
