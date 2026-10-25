import 'dart:async';
import 'dart:convert';

import '../mobile_driver/contracts.dart';

class ChallengeInbox {
  final _received = <String, Map<String, dynamic>>{};
  final _waiting = <String, Completer<Map<String, dynamic>>>{};
  bool accept(Map<String, dynamic> data) {
    final text = data['relay_challenge'];
    if (text is! String || text.length > 1024) return false;
    try {
      final proof = jsonDecode(text);
      if (proof is! Map<String, dynamic> ||
          proof.length != 2 ||
          proof['challenge_id'] is! String ||
          proof['nonce'] is! String) {
        return false;
      }
      if (!RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ).hasMatch(proof['challenge_id']) ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(proof['nonce'])) {
        return false;
      }
      final id = proof['challenge_id'] as String;
      final waiter = _waiting.remove(id);
      if (waiter != null) {
        waiter.complete(proof);
      } else {
        _received[id] = proof;
        while (_received.length > 4) {
          _received.remove(_received.keys.first);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> take(String id) async {
    final ready = _received.remove(id);
    if (ready != null) return ready;
    if (_waiting.length >= 4) {
      throw const PushUnavailable('registration_unavailable');
    }
    final completer = Completer<Map<String, dynamic>>();
    _waiting[id] = completer;
    try {
      return await completer.future.timeout(const Duration(seconds: 30));
    } finally {
      _waiting.remove(id);
    }
  }

  void clear() {
    _received.clear();
    for (final waiter in _waiting.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(const PushUnavailable('cancelled'));
      }
    }
    _waiting.clear();
  }
}
