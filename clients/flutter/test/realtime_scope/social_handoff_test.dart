import 'dart:async';

import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/realtime/social_hints/hints.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old ready cannot dispatch after a social observer and socket close', () async {
    final api = ApiClient();
    final started = Completer<void>(), release = Completer<void>();
    final events = <String?>[];
    final controller = RealtimeController(
      api,
      api.transport.session.scope,
      isReady: () => true,
      expire: () async {},
      invalidatePresence: () {},
      dispatch: (event) => events.add(event.kind),
    );
    addTearDown(controller.dispose);
    final unsubscribe = SocialHints.forTransport(api.transport).subscribe((_) {
      started.complete();
      return release.future;
    });
    addTearDown(unsubscribe);
    controller.synchronizeDeliveryScope();
    final pending = controller.applyEvent(const RealtimeEvent('ready', 'connection.ready', {}));
    await started.future;
    await controller.close();
    release.complete();
    await pending;
    expect(events, isEmpty);
  });
}
