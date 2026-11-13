part of 'delivery.dart';

extension _RealtimeSecurityDelivery on RealtimeDelivery {
  bool _acceptSecurity(RealtimeEvent event) {
    final lane = switch (event.kind) {
      'auth.permissions.invalidated' || 'role.permissions.updated' => 'permissions',
      'session.state_changed' => 'session',
      _ => null,
    };
    if (lane == null) return false;
    if (_securityBusy.contains(lane)) {
      // One follow-up sees every invalidation that arrived while work ran.
      _securityPending[lane] = event;
    } else {
      _startSecurity(lane, event);
    }
    return true;
  }

  void _startSecurity(String lane, RealtimeEvent event) {
    final epoch = _epoch;
    _securityBusy.add(lane);
    unawaited(Future<void>.sync(() => apply(event)).then((_) {
      if (epoch != _epoch) return;
      final next = _securityPending.remove(lane);
      if (next == null) {
        _securityBusy.remove(lane);
      } else {
        _startSecurity(lane, next);
      }
    }, onError: (Object _, StackTrace _) {
      if (epoch == _epoch) _fail();
    }));
  }
}
