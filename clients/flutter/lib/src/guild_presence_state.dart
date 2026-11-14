import 'models.dart';

/// Resolves REST presence hints with the authoritative realtime presence feed.
class GuildPresenceState {
  Set<String>? _onlineUserIds;
  Set<String> _idleUserIds = {};
  final Map<String, MemberPresence> _changes = {};
  bool _unavailable = false;

  bool get unavailable => _unavailable;

  MemberPresence resolve(String userId, MemberPresence fallback) {
    if (_unavailable) return MemberPresence.unknown;
    final changed = _changes[userId];
    if (changed != null) return changed;
    final onlineUserIds = _onlineUserIds;
    if (onlineUserIds == null) return fallback;
    return onlineUserIds.contains(userId)
        ? (_idleUserIds.contains(userId) ? MemberPresence.idle : MemberPresence.online)
        : MemberPresence.offline;
  }

  /// Applies a validated snapshot, returning false and invalidating presence
  /// if the event payload is malformed.
  bool acceptSnapshot(dynamic rawIds, [dynamic rawIdleIds]) {
    if (rawIds is! List || rawIds.any((id) => id is! String || !_isUuid(id))) {
      invalidate();
      return false;
    }
    _onlineUserIds = rawIds.cast<String>().toSet();
    if (rawIdleIds != null && (rawIdleIds is! List || rawIdleIds.any((id) => id is! String || !_isUuid(id)))) {
      invalidate();
      return false;
    }
    _idleUserIds = rawIdleIds == null ? {} : rawIdleIds.cast<String>().toSet();
    _changes.clear();
    _unavailable = false;
    return true;
  }

  /// Applies a single online/offline update. Changes received while the feed
  /// is unavailable remain hidden until the next complete snapshot.
  bool acceptChange(dynamic rawUserId, dynamic rawPresence, [dynamic rawActivityState]) {
    if (rawUserId is! String ||
        !_isUuid(rawUserId) ||
        (rawPresence != 'online' && rawPresence != 'offline') ||
        (rawActivityState != null && (rawPresence != 'online' || (rawActivityState != 'active' && rawActivityState != 'idle')))) {
      invalidate();
      return false;
    }
    _changes[rawUserId] = rawPresence == 'online'
        ? (rawActivityState == 'idle' ? MemberPresence.idle : MemberPresence.online)
        : MemberPresence.offline;
    return true;
  }

  void invalidate() {
    _onlineUserIds = null;
    _idleUserIds = {};
    _changes.clear();
    _unavailable = true;
  }

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);
}
