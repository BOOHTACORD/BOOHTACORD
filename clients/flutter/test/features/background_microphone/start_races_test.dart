import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/background_microphone/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'concurrent callers share one pending native microphone start',
    () async {
      final ready = Completer<bool>();
      final calls = <String>[];
      final session = MicrophoneForegroundSession(
        android: true,
        invoke: (method) {
          calls.add(method);
          return method == 'start' ? ready.future : Future.value(true);
        },
      );
      addTearDown(session.dispose);
      final first = session.start();
      final second = session.start();
      ready.complete(true);
      expect(await first, true);
      expect(await second, true);
      expect(calls, ['start']);
      expect(session.active, true);
    },
  );

  test('superseded start failure cannot stop a replacement session', () async {
    final oldStart = Completer<bool>();
    final calls = <String>[];
    var starts = 0;
    final session = MicrophoneForegroundSession(
      android: true,
      invoke: (method) {
        calls.add(method);
        if (method == 'start' && starts++ == 0) return oldStart.future;
        return Future.value(true);
      },
    );
    addTearDown(session.dispose);
    final obsolete = session.start();
    await session.stop();
    expect(await session.start(), true);
    oldStart.completeError(StateError('old platform operation failed'));
    expect(await obsolete, false);
    expect(session.active, true);
    expect(calls, ['start', 'stop', 'start']);
  });

  test(
    'native service loss invalidates its pending successful reply',
    () async {
      const channel = MicrophoneForegroundSession.channel;
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final ready = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') return ready.future;
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final session = MicrophoneForegroundSession(android: true);
      addTearDown(session.dispose);
      var stopped = 0;
      session.onStopped = () => stopped++;
      final starting = session.start();
      final delivered = Completer<void>();
      messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('stopped')),
        (_) => delivered.complete(),
      );
      await delivered.future;
      ready.complete(true);
      expect(await starting, false);
      expect(stopped, 1);
      expect(session.active, false);
    },
  );
}
