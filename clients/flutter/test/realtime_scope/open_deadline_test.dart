import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('hung upgrade times out, retries and closes a late socket', (
    tester,
  ) async {
    final api = RealtimeApiFake();
    final owner = RealtimeController(
      api,
      SessionScope(),
      isReady: () => true,
      expire: () async {},
      invalidatePresence: () {},
      dispatch: (_) {},
      jitter: () => 0,
    );
    addTearDown(owner.dispose);
    final first = owner.connect();
    expect(owner.connecting, isTrue);
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(owner.connecting, isFalse);
    expect(owner.retry?.isActive, isTrue);
    final late = SocketFake();
    api.opening.complete(late);
    await tester.pump();
    await first;
    expect(late.closed, isTrue);
    await owner.close();
  });
}
