const _resyncReasons = {
  'event_overflow',
  'server_restart',
  'cursor_expired',
  'cursor_invalid',
  'replay_limit',
  'replay_unavailable',
};

bool validResyncPayload(Map<String, dynamic> payload) =>
    payload.length == 1 && _resyncReasons.contains(payload['reason']);
