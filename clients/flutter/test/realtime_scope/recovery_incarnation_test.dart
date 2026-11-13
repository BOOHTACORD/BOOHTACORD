import 'dart:async';

import 'package:boohtacord_desktop/src/features/realtime/lifecycle/delivery.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old recovery cannot dispatch ready after a new socket has recovered', () async {
    final recoveries = <Completer<void>>[], applied = <String>[];
    final delivery = RealtimeDelivery((event) => applied.add(event.id), () {
      final pending = Completer<void>();
      recoveries.add(pending);
      return pending.future;
    }, () => fail('unexpected recovery failure'));
    delivery.accept(const RealtimeEvent('old', 'connection.ready', {}));
    delivery.disconnected();
    delivery.accept(const RealtimeEvent('new', 'connection.ready', {}));
    expect(recoveries, hasLength(2));
    recoveries[1].complete();
    await Future<void>.delayed(Duration.zero);
    expect(applied, ['new']);
    recoveries[0].complete();
    await Future<void>.delayed(Duration.zero);
    expect(applied, ['new']);
    expect(delivery.cursor, isNull);
  });
}
