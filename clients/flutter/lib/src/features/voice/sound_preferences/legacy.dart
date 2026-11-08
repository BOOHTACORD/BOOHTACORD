import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'controller.dart';

class LegacySoundReview {
  Future<bool> review(VoiceSoundController? preferences, bool quiet) async {
    if (preferences?.ready != true) return false;
    if (quiet) {
      await preferences!.update({'enabled': false});
      if (preferences.unsynchronised) return false;
    }
    try {
      await acknowledge();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool blocked = true;
  String? _key;
  Future<void> select(String origin, String account) async {
    _key =
        'voice-sound-legacy-reviewed:v1:${base64UrlEncode(utf8.encode('$origin\n$account'))}';
    blocked = true;
    try {
      final storage = await SharedPreferences.getInstance();
      blocked =
          storage.getBool(_key!) != true &&
          [
            'voice-screen-start-sound:v1',
            'voice-room-event-sounds:v1',
          ].any((key) => storage.getBool(key) == false);
    } catch (_) {
      /* Keep the device quiet if ownership cannot be checked. */
    }
  }

  Future<void> acknowledge() async {
    final key = _key;
    if (key == null) return;
    final storage = await SharedPreferences.getInstance();
    if (!await storage.setBool(key, true))
      throw StateError('Unable to persist sound choice');
    if (_key == key) blocked = false;
  }
}
