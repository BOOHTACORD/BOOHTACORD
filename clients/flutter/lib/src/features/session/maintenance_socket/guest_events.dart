part of 'guest.dart';

extension _GuestEvents on MaintenanceGuestSocket {
  void _receive(int epoch, dynamic raw) {
    if (!_current(epoch) || raw is! String) return;
    try {
      final source = jsonDecode(raw);
      if (source is! Map<String, dynamic> ||
          source.length != 4 ||
          !source.keys.toSet().containsAll({
            'event_id',
            'kind',
            'occurred_at',
            'payload',
          }) ||
          source['event_id'] is! String ||
          (source['event_id'] as String).isEmpty ||
          source['occurred_at'] is! String ||
          DateTime.tryParse(source['occurred_at'] as String) == null ||
          source['payload'] is! Map<String, dynamic>) {
        _fail(epoch);
        return;
      }
      final kind = source['kind'],
          payload = source['payload'] as Map<String, dynamic>;
      if (isMaintenanceKind(kind) && !validNewRealtimeEnvelope(source)) {
        _fail(epoch);
        return;
      }
      if (kind == 'connection.ready' && !_ready && payload.isEmpty) {
        _ready = true;
        _liveness?.observe(kind as String, source);
        return;
      }
      if (kind == 'connection.heartbeat') {
        if (_liveness?.observe(kind as String, source) != true) _fail(epoch);
        return;
      }
      if (!_ready ||
          (kind != 'maintenance.snapshot' && kind != 'maintenance.changed') ||
          !state.accept(
            _token!,
            RealtimeEvent(
              source['event_id'] as String,
              kind as String,
              payload,
            ),
          )) {
        _fail(epoch);
        return;
      }
      if (kind == 'maintenance.snapshot') {
        _timeout?.cancel();
        _timeout = null;
        _attempt = 0;
      }
      _liveness?.observe(kind, source);
    } catch (_) {
      _fail(epoch);
    }
  }
}
