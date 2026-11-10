part of 'delivery.dart';

extension _RealtimeDeliveryPump on RealtimeDelivery {
  void _pump() {
    if (_busy) return;
    while (_queue.isNotEmpty) {
      final event = _queue.removeFirst();
      final durable = durableRealtimeKinds.contains(event.kind);
      if (durable && _seen.contains((event.kind, event.id))) continue;
      final recovery =
          event.kind == 'connection.resync_required' ||
          event.kind == 'connection.ready' && _needsRecovery;
      if (event.kind == 'connection.resync_required') {
        cursor = null;
        _seen.clear();
        _needsRecovery = true;
      }
      final epoch = _epoch;
      void complete() {
        if (epoch != _epoch) return;
        if (durable) {
          _seen.add((event.kind, event.id));
          if (_seen.length > 2048) _seen.remove(_seen.first);
          cursor = event.id;
        }
        if (event.kind == 'voice.lease_revoked') _revocations.remove(event.id);
        if (recovery) _needsRecovery = false;
      }

      try {
        final work = recovery
            ? _recoverAndApply(event)
            : event.kind == 'voice.lease_revoked'
            ? _revocations[event.id] ?? apply(event)
            : apply(event);
        if (work is Future) {
          _busy = true;
          unawaited(
            work.then(
              (_) {
                if (epoch != _epoch) return;
                complete();
                _busy = false;
                _pump();
              },
              onError: (Object _, StackTrace _) {
                if (epoch == _epoch) _fail();
              },
            ),
          );
          return;
        }
        complete();
      } catch (_) {
        _fail();
        return;
      }
    }
  }
}
