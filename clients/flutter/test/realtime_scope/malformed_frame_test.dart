import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  for (final raw in <Object>['{"kind":', '[]', 'null', <int>[1, 2]]) {
    test('malformed or binary frame closes the authenticated socket', () async {
      final api = RealtimeApiFake();
      final socket = SocketFake();
      final controller = RealtimeController(
        api,
        api.transport.session.scope,
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: (_) => fail('invalid frame dispatched'),
      );
      addTearDown(controller.dispose);
      controller.socket = socket;
      controller.synchronizeDeliveryScope();
      controller.receive(raw);
      expect(socket.closed, isTrue);
      expect(controller.socket, isNull);
    });
  }
}
