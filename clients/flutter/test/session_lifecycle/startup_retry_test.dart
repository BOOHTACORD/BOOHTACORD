import 'dart:async';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';
import 'fake_effects.dart';

void main() {
  for (final outcome in ['account', 'signedOut', 'failure']) {
    testWidgets('late $outcome cannot replace a successful retry', (
      tester,
    ) async {
      final pending = Completer<SessionUser?>();
      final api = SessionFakeApi()..restore = pending;
      var prepared = 0, ready = 0;
      String? error;
      final previous = const SessionUser(accountId: 'previous', role: 'MEMBER');
      final session = SessionController(
        api,
        startupTimeout: const Duration(seconds: 1),
        effects: effects(
          prepare: (_) async {
            prepared++;
          },
          ready: () async {
            ready++;
          },
          error: (value) => error = value,
        ),
      )..user = previous;
      addTearDown(session.dispose);
      final first = session.initialize();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await first;
      expect(session.phase, AppPhase.connectionError);
      expect(session.user, same(previous));
      api.restore = null;
      await session.initialize();
      expect(session.phase, AppPhase.ready);
      expect(session.user?.accountId, 'account');
      expect(error, isNull);
      if (outcome == 'failure') {
        pending.completeError(const ApiFailure('old failure'));
      } else {
        pending.complete(outcome == 'signedOut' ? null : previous);
      }
      await tester.pump();
      expect(session.phase, AppPhase.ready);
      expect(session.user?.accountId, 'account');
      expect(prepared, 1);
      expect(ready, 1);
      expect(error, isNull);
    });
  }
}
