import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';

import 'fakes.dart';

void main() {
  test(
    'socket loss with an expired session clears ownership without retry',
    () async {
      final api = RealtimeApiFake(), scope = SessionScope();
      final expired = Completer<void>();
      final owner = RealtimeController(
        api,
        scope,
        isReady: () => true,
        expire: () async {
          scope.close();
          expired.complete();
        },
        invalidatePresence: () {},
        dispatch: (_) {},
      );
      addTearDown(owner.dispose);
      final socket = SocketFake();
      api.opening.complete(socket);
      await owner.connect();
      await socket.close();
      await api.checking.future;
      api.restored.complete(null);
      await expired.future.timeout(const Duration(seconds: 2));
      expect(owner.retry, isNull);
      expect(owner.socket, isNull);
    },
  );
}
