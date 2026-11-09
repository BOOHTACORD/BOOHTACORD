import 'dart:async';

import 'package:boohtacord_desktop/src/features/realtime/lifecycle/delivery.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native delivery applies revoke with a full queue', (
    tester,
  ) async {
    final pending = Completer<void>();
    final applied = <String>[];
    var failures = 0;
    final delivery = RealtimeDelivery(
      (event) {
        applied.add(event.id);
        return event.id == 'slow' ? pending.future : null;
      },
      () {},
      () => failures++,
      maxPending: 2,
    );
    RealtimeEvent event(String id, [String kind = 'message.updated']) =>
        RealtimeEvent(id, kind, const {});

    delivery.accept(event('slow'));
    delivery.accept(event('queued-1'));
    delivery.accept(event('queued-2'));
    delivery.accept(event('revoked', 'voice.lease_revoked'));
    expect(applied, ['slow', 'revoked']);
    expect(failures, 1);
    pending.complete();
    await tester.pump();
    expect(delivery.cursor, isNull);
  });

  testWidgets('native dedup keeps a different kind with the same ID', (
    tester,
  ) async {
    final applied = <String?>[];
    final delivery = RealtimeDelivery(
      (event) => applied.add(event.kind),
      () {},
      () => fail('unexpected failure'),
    );
    delivery.accept(const RealtimeEvent('same', 'message.updated', {}));
    delivery.accept(const RealtimeEvent('same', 'voice.lease_revoked', {}));
    await tester.pump();
    expect(applied, ['message.updated', 'voice.lease_revoked']);
  });
}
