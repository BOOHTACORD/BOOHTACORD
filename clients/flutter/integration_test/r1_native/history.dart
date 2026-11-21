import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/conversation/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';

import 'harness.dart';
import 'fixtures.dart';

extension R1History on R1Harness {
  Future<void> history() async {
    await real(() => app.workspace.selectChannel(text));
    await real(
      () => api.sendMessage(
        text.id,
        '68900000-0000-4000-8000-000000000001',
        'Synthetic native R1',
      ),
    );
    await wait(
      () =>
          app.conversation.messages.any((m) => m.body == 'Synthetic native R1'),
    );
    await real(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await wait(() => app.realtime.delivery.cursor != null);
    final previousSocket = app.realtime.socket;
    api.durableCursorSent = false;
    await real(() => previousSocket!.close());
    await wait(() => fresh && app.realtime.socket != previousSocket);
    expect(api.durableCursorSent, isTrue);
    expect(
      app.conversation.messages
          .where((m) => m.body == 'Synthetic native R1')
          .length,
      1,
    );
    report['ordinary_reconnect_durable_replay'] = true;
    final held = api.holdHistory();
    await real(() async {
      app.workspace.selectedChannel = null;
      app.conversation.clearText();
      final pending = app.workspace.refreshTopology(strict: true);
      await held.reached.future.timeout(const Duration(seconds: 20));
      await app.realtime.close();
      held.finish();
      await pending;
    });
    expect(app.conversation.messages, isEmpty);
    expect(app.conversation.loadingMessages, isFalse);
    await real(app.realtime.reconnectNow);
    await wait(
      () =>
          fresh &&
          app.conversation.messages.any((m) => m.body == 'Synthetic native R1'),
    );
    expect(
      app.conversation.messages
          .where((m) => m.body == 'Synthetic native R1')
          .length,
      1,
    );
    await real(() => app.workspace.selectChannel(voice));
    await real(steady);
    report['late_history_fenced_then_recovered_once'] = true;
    report['durable_cursor_sent'] = api.durableCursorSent;
  }
}
