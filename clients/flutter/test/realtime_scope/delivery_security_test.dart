import 'dart:async';

import 'package:boohtacord_desktop/src/features/realtime/lifecycle/delivery.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';
import 'package:flutter_test/flutter_test.dart';

RealtimeEvent event(String id, String kind) => RealtimeEvent(id, kind, const {});
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('security hints bypass blocked ordinary work without changing cursor', () async {
    final blocked = Completer<void>();
    final applied = <String>[];
    final delivery = RealtimeDelivery((e) {
      applied.add(e.kind!);
      return e.id == 'blocked' ? blocked.future : null;
    }, () {}, () => fail('unexpected recovery'));
    delivery.accept(event('blocked', 'message.updated'));
    for (var i = 0; i < 255; i++) {
      delivery.accept(event('$i', 'message.updated'));
    }
    delivery.accept(event('p', 'auth.permissions.invalidated'));
    delivery.accept(event('s', 'session.state_changed'));
    await tick();
    expect(applied, containsAll(['auth.permissions.invalidated', 'session.state_changed']));
    expect(delivery.cursor, isNull);
    delivery.reset();
    blocked.complete();
    await tick();
    expect(delivery.cursor, isNull);
  });

  test('permission refresh is serialized and catches hints received during it', () async {
    final first = Completer<void>();
    final applied = <String>[];
    final delivery = RealtimeDelivery((e) {
      applied.add(e.id);
      return e.id == 'one' ? first.future : null;
    }, () {}, () => fail('unexpected recovery'));
    delivery.accept(event('one', 'role.permissions.updated'));
    delivery.accept(event('two', 'auth.permissions.invalidated'));
    delivery.accept(event('three', 'role.permissions.updated'));
    await tick();
    expect(applied, ['one']);
    first.complete();
    await tick();
    expect(applied, ['one', 'three']);
    expect(delivery.cursor, isNull);
  });

  test('reset fences queued security work from the old connection', () async {
    final first = Completer<void>();
    final applied = <String>[];
    final delivery = RealtimeDelivery((e) {
      applied.add(e.id);
      return e.id == 'one' ? first.future : null;
    }, () {}, () => fail('unexpected recovery'));
    delivery.accept(event('one', 'auth.permissions.invalidated'));
    delivery.accept(event('two', 'role.permissions.updated'));
    delivery.reset();
    first.complete();
    await tick();
    expect(applied, ['one']);
  });

  test('session hint does not wait for a blocked permission refresh', () async {
    final permission = Completer<void>();
    final applied = <String>[];
    final delivery = RealtimeDelivery((e) {
      applied.add(e.id);
      return e.id == 'permission' ? permission.future : null;
    }, () {}, () => fail('unexpected recovery'));
    delivery.accept(event('permission', 'auth.permissions.invalidated'));
    delivery.accept(event('session', 'session.state_changed'));
    await tick();
    expect(applied, ['permission', 'session']);
    delivery.disconnected();
    permission.complete();
    await tick();
    expect(delivery.cursor, isNull);
  });

  test('security callback failure forces full recovery', () async {
    var failures = 0;
    final delivery = RealtimeDelivery((_) => Future<void>.error(StateError('failed')),
        () {}, () => failures++);
    delivery.accept(event('one', 'auth.permissions.invalidated'));
    await tick();
    expect(failures, 1);
    expect(delivery.cursor, isNull);
  });
}
