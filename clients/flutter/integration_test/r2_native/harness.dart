import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../r1_native/harness.dart';
import '../r1_native/fixtures.dart';
import 'control.dart';

class R2Harness {
  R2Harness(this.h);
  final R1Harness h;
  Future<void> arm(String mode) async {
    await h.real(() => control(mode));
  }

  Future<Map<String, dynamic>> stats() async => (await h.real(control))!;
  Future<void> entered() async {
    for (var i = 0; i < 50; i++) {
      if ((await stats())['seen'] == 1) return;
      await h.real(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    fail('Owned fault was not reached');
  }

  Future<void> reconnect() async {
    await h.real(() async {
      unawaited(h.app.realtime.reconnectNow());
    });
  }

  Future<void> healthy() async {
    await h.wait(() => h.fresh && h.participants == 2);
    expect(h.app.room?.connectionState == lk.ConnectionState.connected, isTrue);
    await h.real(h.steady);
  }

  Future<void> setup() async {
    await h.setup();
    await h.fixtures();
    await h.real(() => h.app.joinVoice(h.voice, listenerOnly: true));
    await healthy();
  }
}
