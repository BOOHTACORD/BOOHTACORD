import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';

import '../fakes.dart';

void main() {
  for (final boundary in ['logout', 'server', 'installation', 'dispose']) {
    test('late successful upgrade is closed after $boundary', () async {
      final api = RealtimeApiFake(), scope = SessionScope();
      var disposed = false, expirations = 0;
      final owner = RealtimeController(
        api,
        scope,
        isReady: () => true,
        expire: () async {
          expirations++;
        },
        invalidatePresence: () {},
        dispatch: (_) {},
      );
      addTearDown(() {
        if (!disposed) owner.dispose();
      });
      final pending = owner.connect();
      switch (boundary) {
        case 'logout':
          scope.close();
          await owner.close();
        case 'server':
          api.transport.session.baseUrl = 'https://other.example/api/v1';
        case 'installation':
          api.transport.session.telemetry.bindInstallation(
            '11111111-1111-4111-8111-111111111111',
          );
        case 'dispose':
          owner.dispose();
          disposed = true;
      }
      final late = SocketFake();
      api.opening.complete(late);
      await pending;
      // Cancellation may finish connect before the original upgrade's callback.
      await Future<void>.delayed(Duration.zero);
      expect(late.closed, isTrue);
      expect(owner.socket, isNull);
      expect(owner.retry, isNull);
      expect(expirations, 0);
    });
  }
}
