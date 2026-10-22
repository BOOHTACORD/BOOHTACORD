import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/delivery.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';

void main() {
  RealtimeEvent event(String id, [String kind = 'message.updated']) =>
      RealtimeEvent(id, kind, const {});
  test(
    'cursor advances only after applied durable work, in order and once',
    () async {
      final pending = Completer<void>(), applied = <String>[];
      final delivery = RealtimeDelivery(
        (e) async {
          applied.add(e.id);
          if (e.id == 'one') await pending.future;
        },
        () async {},
        () => fail('unexpected recovery'),
      );
      delivery.accept(event('one'));
      delivery.accept(event('two'));
      delivery.accept(event('two'));
      expect(delivery.cursor, isNull);
      expect(applied, ['one']);
      pending.complete();
      await Future<void>.delayed(Duration.zero);
      expect(applied, ['one', 'two']);
      expect(delivery.cursor, 'two');
      delivery.accept(event('hint', 'screen_viewers.changed'));
      await Future<void>.delayed(Duration.zero);
      expect(delivery.cursor, 'two');
    },
  );
  test(
    'handler failure clears cursor and forces full recovery on ready',
    () async {
      var recoveries = 0, failures = 0;
      final delivery = RealtimeDelivery(
        (_) => throw StateError('offline'),
        () async {
          recoveries++;
        },
        () {
          failures++;
        },
      );
      delivery.accept(event('bad'));
      await Future<void>.delayed(Duration.zero);
      expect(delivery.cursor, isNull);
      expect(failures, 1);
      delivery.accept(event('ready', 'connection.ready'));
      await Future<void>.delayed(Duration.zero);
      expect(recoveries, 1);
    },
  );
  test('overflow cannot acknowledge late in-flight work', () async {
    final pending = Completer<void>();
    var failures = 0;
    final delivery = RealtimeDelivery((_) => pending.future, () async {}, () {
      failures++;
    }, maxPending: 2);
    for (final id in ['one', 'two', 'three', 'four']) {
      delivery.accept(event(id));
    }
    expect(failures, 1);
    pending.complete();
    await Future<void>.delayed(Duration.zero);
    expect(delivery.cursor, isNull);
  });
  test('disconnect preserves settled cursor but not incomplete work', () async {
    final pending = Completer<void>();
    final delivery = RealtimeDelivery(
      (e) => e.id == 'late' ? pending.future : null,
      () async {},
      () {},
    );
    delivery.accept(event('applied'));
    delivery.disconnected();
    expect(delivery.cursor, 'applied');
    delivery.accept(event('late'));
    delivery.disconnected();
    pending.complete();
    await Future<void>.delayed(Duration.zero);
    expect(delivery.cursor, isNull);
  });
  test(
    'scope reset prevents a late event from advancing the new account cursor',
    () async {
      final pending = Completer<void>();
      final delivery = RealtimeDelivery(
        (_) => pending.future,
        () async {},
        () {},
      );
      delivery.accept(event('old'));
      delivery.reset();
      pending.complete();
      await Future<void>.delayed(Duration.zero);
      expect(delivery.cursor, isNull);
    },
  );
  test('expired cursor runs full recovery and never becomes a control-event cursor', () async {
    var recoveries = 0;
    final delivery = RealtimeDelivery((_) {}, () async {
      recoveries++;
    }, () {});
    delivery.accept(event('one'));
    delivery.accept(event('resync', 'connection.resync_required'));
    await Future<void>.delayed(Duration.zero);
    delivery.accept(event('ready', 'connection.ready'));
    await Future<void>.delayed(Duration.zero);
    expect(delivery.cursor, isNull);
    expect(recoveries, 1);
  });
}
