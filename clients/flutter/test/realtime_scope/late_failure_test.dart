import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';

import 'fakes.dart';

void main() {
  for (final changed in ['server', 'installation', 'dispose']) {
    test('late open failure cannot retry after $changed changes', () async {
      final api = RealtimeApiFake();
      final owner = RealtimeController(
        api,
        SessionScope(),
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: (_) {},
      );
      var disposed = false;
      addTearDown(() {
        if (!disposed) owner.dispose();
      });
      final pending = owner.connect();
      if (changed == 'server') {
        api.transport.session.baseUrl = 'https://another.example/api/v1';
      } else if (changed == 'installation') {
        api.transport.session.telemetry.bindInstallation(
          '11111111-1111-4111-8111-111111111111',
        );
      } else {
        owner.dispose();
        disposed = true;
      }
      api.opening.completeError(const SocketException('late owned failure'));
      await pending;
      expect(owner.retry, isNull);
      expect(api.opens, 1);
    });
  }
}
