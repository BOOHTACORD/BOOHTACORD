import 'dart:async';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';
import 'fake_effects.dart';

class StartupApi extends SessionFakeApi {
  StartupApi(this.stage, this.gate);
  final String stage;
  final Completer<void> gate;
  int checks = 0;
  @override
  Future<void> initialize() async {
    if (stage == 'storage' && !gate.isCompleted) await gate.future;
  }

  @override
  Future<SessionUser?> currentSession() async {
    checks++;
    if (stage == 'session' && !gate.isCompleted) await gate.future;
    return const SessionUser(accountId: 'restored', role: 'MEMBER');
  }
}

void main() {
  for (final stage in ['storage', 'platform', 'session', 'prepare']) {
    testWidgets('$stage timeout fences late work and permits manual retry', (
      tester,
    ) async {
      final gate = Completer<void>();
      final api = StartupApi(stage, gate);
      var prepared = 0, ready = 0, invalidated = 0, changes = 0;
      String? error;
      late SessionController session;
      final ownerEffects = effects(
        initialize: () async {
          if (stage == 'platform' && !gate.isCompleted) await gate.future;
        },
        prepare: (_) async {
          prepared++;
          final ticket = session.scope.capture();
          if (stage == 'prepare' && !gate.isCompleted) await gate.future;
          if (!ticket.isActive) return;
          ready++;
        },
        invalidate: () => invalidated++,
        error: (value) => error = value,
      );
      session = SessionController(
        api,
        startupTimeout: const Duration(seconds: 1),
        effects: ownerEffects,
      )..addListener(() => changes++);
      addTearDown(session.dispose);
      final first = session.initialize();
      await tester.pump();
      final expired = session.scope.capture();
      await tester.pump(const Duration(seconds: 1));
      await first;
      expect(session.phase, AppPhase.connectionError);
      expect(session.user, isNull);
      expect(error, contains('Подключение не завершилось вовремя'));
      expect(changes, 2, reason: 'the retry screen must be notified');
      expect(expired.isActive, isFalse);
      expect(invalidated, 1);
      gate.complete();
      await tester.pump();
      expect(session.user, isNull);
      expect(
        ready,
        0,
        reason: 'expired preparation cannot apply account state',
      );
      expect(prepared, stage == 'prepare' ? 1 : 0);
      expect(api.checks, ['session', 'prepare'].contains(stage) ? 1 : 0);
      await session.initialize();
      expect(session.phase, AppPhase.ready);
      expect(session.user?.accountId, 'restored');
      expect(session.scope.capture().isActive, isTrue);
      expect(ready, 1);
      expect(error, isNull);
    });
  }
}
