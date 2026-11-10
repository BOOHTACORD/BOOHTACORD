import 'dart:async';
import 'dart:collection';

import 'event.dart';

part 'delivery_pump.dart';

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
  final _seen = <(String?, String)>{};
  final _revocations = <String, Future<void>>{};
  String? cursor;
  bool _busy = false, _needsRecovery = true;
  int _epoch = 0;

  void accept(RealtimeEvent event) {
    if (event.kind == 'voice.lease_revoked') {
      if (_seen.contains((event.kind, event.id)) ||
          _revocations.containsKey(event.id)) {
        return;
      }
      final epoch = _epoch;
      final work = Future<void>.sync(() => apply(event));
      _revocations[event.id] = work;
      unawaited(
        work.catchError((Object _, StackTrace _) {
          if (epoch == _epoch) _fail();
        }),
      );
    }
    if (event.kind == 'screen_viewers.changed' &&
        _queue.any((e) => e.kind == event.kind)) {
      return;
    }
    if (_queue.length >= maxPending) {
      _fail();
      return;
    }
    _queue.add(event);
    _pump();
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
    _revocations.clear();
    cursor = null;
    _needsRecovery = true;
  }
}
