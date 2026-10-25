const int _maxEpochMs = 9007199254740991;

Map<String, Object> evaluateNotificationPolicy(Map<String, dynamic> input) {
  if (input['version'] != 1) return deny('unsupported_version');
  for (final key in ['actor_id', 'recipient_id', 'mode', 'kind']) {
    if (input[key] is! String) return deny('invalid');
  }
  for (final key in ['paused_until_ms', 'now_ms', 'occurred_at_ms']) {
    if (input[key] is! int) return deny('invalid');
  }

  final actorId = (input['actor_id'] as String?) ?? '';
  final recipientId = (input['recipient_id'] as String?) ?? '';
  if (actorId.isEmpty || recipientId.isEmpty) return deny('invalid');
  final configuredTtl = input['ttl_ms'] ?? 0;
  if (configuredTtl is! int ||
      (configuredTtl != 0 &&
          (configuredTtl < 60000 || configuredTtl > 86400000))) {
    return deny('invalid');
  }
  final ttl = configuredTtl == 0 ? 3600000 : configuredTtl;

  final mode = (input['mode'] as String?) ?? '';
  if (mode != 'all' && mode != 'mentions' && mode != 'none') {
    return deny('invalid');
  }

  final pausedUntilMs = (input['paused_until_ms'] as num).toInt();
  final nowMs = (input['now_ms'] as num).toInt();
  final occurredAtMs = (input['occurred_at_ms'] as num).toInt();
  if (pausedUntilMs < 0 ||
      nowMs < 0 ||
      occurredAtMs < 0 ||
      pausedUntilMs > _maxEpochMs ||
      nowMs > _maxEpochMs ||
      occurredAtMs > _maxEpochMs ||
      occurredAtMs > nowMs) {
    return deny('invalid');
  }

  final operatorAvailable = (input['operator_available'] as bool?) ?? false;
  if (!operatorAvailable) return deny('unavailable');

  final accountEnabled = (input['account_enabled'] as bool?) ?? false;
  final deviceConsent = (input['device_consent'] as bool?) ?? false;
  if (!accountEnabled || !deviceConsent) return deny('no_consent');

  if (actorId == recipientId) return deny('self');

  final kind = (input['kind'] as String?) ?? '';
  if (kind != 'DM' && kind != 'TEXT') return deny('event_kind');

  final deleted = (input['deleted'] as bool?) ?? false;
  if (deleted) return deny('deleted');

  final archived = (input['archived'] as bool?) ?? false;
  if (archived) return deny('archived');

  final revoked = (input['revoked'] as bool?) ?? false;
  if (revoked) return deny('revoked');

  final read = (input['read'] as bool?) ?? false;
  if (read) return deny('read');

  if (nowMs - occurredAtMs >= ttl) return deny('expired');

  if (nowMs < pausedUntilMs) return deny('paused');

  if (mode == 'none') return deny('muted');
  if (mode == 'mentions' && !((input['mentioned'] as bool?) ?? false)) {
    return deny('not_mentioned');
  }

  return {'eligible': true, 'reason': 'eligible'};
}

Map<String, Object> deny(String reason) => {
  'eligible': false,
  'reason': reason,
};
