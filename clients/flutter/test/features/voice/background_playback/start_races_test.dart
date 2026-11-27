import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/background_playback/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('concurrent playback callers share one native admission', () async {
    final ready = Completer<bool>();
    final calls = <String>[];
    final session = VoicePlaybackForegroundSession(
      android: true,
      invoke: (method) {
        calls.add(method);
        if (method == 'start') {
          return calls.where((value) => value == 'start').length == 1
              ? ready.future
              : Future.value(false);
        }
        return Future.value(true);
      },
    );
    addTearDown(session.dispose);
    final first = session.start(), second = session.start();
    await Future<void>.delayed(Duration.zero);
    ready.complete(true);
    expect(await first, true);
    expect(await second, true);
    expect(session.active, true);
    expect(calls, ['start']);
  });

  test('failed obsolete playback start cannot stop its replacement', () async {
    final old = Completer<bool>();
    final calls = <String>[];
    var starts = 0;
    final session = VoicePlaybackForegroundSession(
      android: true,
      invoke: (method) {
        calls.add(method);
        if (method == 'start' && starts++ == 0) return old.future;
        return Future.value(true);
      },
    );
    addTearDown(session.dispose);
    final pending = session.start();
    await session.stop();
    expect(await session.start(), true);
    old.completeError(StateError('obsolete platform failure'));
    expect(await pending, false);
    expect(session.active, true);
    expect(calls, ['start', 'stop', 'start']);
  });

  test(
    'native loss permits a fresh start before the old reply arrives',
    () async {
      const channel = VoicePlaybackForegroundSession.channel;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final old = Completer<bool>();
      var starts = 0, stopped = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start' && starts++ == 0) return old.future;
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final session = VoicePlaybackForegroundSession(android: true);
      addTearDown(session.dispose);
      session.onStopped = () => stopped++;
      final pending = session.start();
      final delivered = Completer<void>();
      messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('stopped'),
        ),
        (_) => delivered.complete(),
      );
      await delivered.future;
      expect(await session.start(), true);
      old.complete(true);
      expect(await pending, false);
      expect(session.active, true);
      expect(starts, 2);
      expect(stopped, 1);
    },
  );
}
