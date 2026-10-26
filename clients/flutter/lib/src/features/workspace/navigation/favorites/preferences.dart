import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../voice/volume_preferences/model.dart';

/// Stores channel favorites within the active account and deployment scope.
class ChannelFavoritesPreferences {
  ChannelFavoritesPreferences({
    required this.accountId,
    required String baseUrl,
    bool Function()? current,
  }) : _origin = deploymentOrigin(baseUrl),
       _current = current ?? _alwaysCurrent;

  final String accountId;
  final String _origin;
  final bool Function() _current;

  static bool _alwaysCurrent() => true;

  String get key =>
      'channel-favorites:v1:${Uri.encodeComponent(_origin)}:${Uri.encodeComponent(accountId)}';

  Future<Set<String>> read() async {
    if (!_current()) return <String>{};
    try {
      final storage = await SharedPreferences.getInstance();
      if (!_current()) return <String>{};
      final raw = storage.getString(key);
      if (raw == null) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.length > 500) return <String>{};
      if (decoded.any((value) => value is! String || !_validId(value))) {
        return <String>{};
      }
      return decoded.cast<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<bool> save(Iterable<String> channelIds) async {
    if (!_current()) return false;
    final values = channelIds.where(_validId).toSet().take(500).toList();
    try {
      final storage = await SharedPreferences.getInstance();
      if (!_current()) return false;
      return await storage.setString(key, jsonEncode(values));
    } catch (_) {
      return false;
    }
  }

  static bool _validId(String value) =>
      value.isNotEmpty &&
      value.length <= 100 &&
      RegExp(r'^[a-zA-Z0-9:_-]+$').hasMatch(value);
}
