import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/delivery.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';

RealtimeEvent event(String id, [String kind = 'message.updated']) =>
    RealtimeEvent(id, kind, const {});

void main() {
  test(
    'a different event kind with the same ID cannot hide a revoke',
    () async {
      final applied = <String?>[];
      final delivery = RealtimeDelivery(
        (event) => applied.add(event.kind),
        () {},
        () => fail('unexpected failure'),
      );
      delivery.accept(event('same', 'message.updated'));
      delivery.accept(event('same', 'voice.lease_revoked'));
      await Future<void>.delayed(Duration.zero);
      expect(applied, ['message.updated', 'voice.lease_revoked']);
    },
  );

  test('applies revoke immediately while prior delivery is blocked', () async {
    final pending = Completer<void>();
    final applied = <String>[];
    final delivery = RealtimeDelivery(
      (e) {
        applied.add(e.id);
        return e.id == 'slow' ? pending.future : null;
      },
      () {},
      () => fail('unexpected failure'),
    );
    delivery.accept(event('slow'));
    delivery.accept(event('revoke', 'voice.lease_revoked'));
    delivery.accept(event('revoke', 'voice.lease_revoked'));
    expect(applied, ['slow', 'revoke']);
    expect(delivery.cursor, isNull);
    pending.complete();
    await Future<void>.delayed(Duration.zero);
    expect(applied, ['slow', 'revoke']);
    expect(delivery.cursor, 'revoke');
  });

  test('applies revoke even when accepting it overflows the backlog', () async {
    final pending = Completer<void>();
    final applied = <String>[];
    var failures = 0;
    final delivery = RealtimeDelivery(
      (e) {
        applied.add(e.id);
        return e.id == 'slow' ? pending.future : null;
      },
      () {},
      () => failures++,
      maxPending: 2,
    );
    delivery.accept(event('slow'));
    delivery.accept(event('queued-one'));
    delivery.accept(event('queued-two'));
    delivery.accept(event('revoke', 'voice.lease_revoked'));
    expect(applied, ['slow', 'revoke']);
    expect(failures, 1);
    pending.complete();
    await Future<void>.delayed(Duration.zero);
    expect(delivery.cursor, isNull);
  });

  test('failed immediate revoke forces recovery and can be replayed', () async {
    final slow = Completer<void>(), revoke = Completer<void>();
    var attempts = 0, failures = 0;
    final delivery = RealtimeDelivery(
      (e) {
        if (e.id == 'slow') return slow.future;
        if (e.id == 'revoke' && ++attempts == 1) return revoke.future;
        return null;
      },
      () {},
      () => failures++,
    );
    delivery.accept(event('slow'));
    delivery.accept(event('revoke', 'voice.lease_revoked'));
    revoke.completeError(StateError('synthetic failure'));
    await Future<void>.delayed(Duration.zero);
    expect(failures, 1);
    expect(delivery.cursor, isNull);
    slow.complete();
    await Future<void>.delayed(Duration.zero);
    expect(delivery.cursor, isNull);
    delivery.accept(event('revoke', 'voice.lease_revoked'));
    await Future<void>.delayed(Duration.zero);
    expect(attempts, 2);
    expect(delivery.cursor, 'revoke');
  });
}
