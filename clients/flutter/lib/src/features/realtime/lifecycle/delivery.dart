import 'dart:async';
import 'dart:collection';

import 'event.dart';

// Only these server journal kinds can be used as replay cursors. Ephemeral
// presence/profile/permission/audience hints must never advance the cursor.
const durableRealtimeKinds = {
  'voice.lease_revoked',
  'channel.updated',
  'message.created',
  'message.updated',
  'message.deleted',
  'direct_message.message_created',
  'direct_message.message_updated',
  'direct_message.message_deleted',
  'message.reactions_updated',
  'message.pins_updated',
  'direct_message.reactions_updated',
};

class RealtimeDelivery {
  RealtimeDelivery(
    this.apply,
    this.recover,
    this.onFailure, {
    this.maxPending = 256,
  });
  final FutureOr<void> Function(RealtimeEvent) apply;
  final FutureOr<void> Function() recover;
  final void Function() onFailure;
  final int maxPending;
  final _queue = Queue<RealtimeEvent>();
  final _seen = LinkedHashSet<String>();
  String? cursor;
  bool _busy = false, _needsRecovery = true;
  int _epoch = 0;

  void accept(RealtimeEvent event) {
    if (event.kind == 'screen_viewers.changed' &&
        _queue.any((e) => e.kind == event.kind))
      return;
    if (_queue.length >= maxPending) {
      _fail();
      return;
    }
    _queue.add(event);
    _pump();
  }

  void _pump() {
    if (_busy) return;
    while (_queue.isNotEmpty) {
      final event = _queue.removeFirst();
      final durable = durableRealtimeKinds.contains(event.kind);
      if (durable && _seen.contains(event.id)) continue;
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
          _seen.add(event.id);
          if (_seen.length > 2048) _seen.remove(_seen.first);
          cursor = event.id;
        }
        if (recovery) _needsRecovery = false;
      }

      try {
        final work = recovery ? _recoverAndApply(event) : apply(event);
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
              onError: (Object _, StackTrace __) {
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

  Future<void> _recoverAndApply(RealtimeEvent event) async {
    await recover();
    if (event.kind == 'connection.ready') await apply(event);
  }

  void _fail() {
    reset();
    onFailure();
  }

  void disconnected() {
    // An interrupted application cannot be claimed durable. The next socket
    // starts from a full snapshot instead of acknowledging that event.
    if (_busy || _queue.isNotEmpty) {
      reset();
      return;
    }
    if (cursor == null) _needsRecovery = true;
  }

  void reset() {
    _epoch++;
    _busy = false;
    _queue.clear();
    _seen.clear();
    cursor = null;
    _needsRecovery = true;
  }
}
