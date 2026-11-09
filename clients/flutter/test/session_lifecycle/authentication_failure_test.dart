import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';

import 'fake_api.dart';
import 'fake_effects.dart';

void main() {
  test('failed workspace handoff cannot leave the session ready', () async {
    final session = SessionController(
      SessionFakeApi(),
      effects: effects(ready: () async => throw TimeoutException('handoff')),
    );
    addTearDown(session.dispose);
    session.phase = AppPhase.signedOut;
    await expectLater(
      session.authenticate('member', 'password', register: false),
      throwsA(isA<TimeoutException>()),
    );
    expect(session.phase, AppPhase.connectionError);
  });
}
