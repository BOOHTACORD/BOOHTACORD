import 'dart:async';

import 'package:boohtacord_desktop/src/features/voice/background_playback/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non Android does not start a native playback service', () async {
    var calls = 0;
    final session = VoicePlaybackForegroundSession(
      android: false,
      invoke: (_) async {
        calls++;
        return true;
      },
    );

    expect(await session.canStart(), isTrue);
    expect(await session.start(), isTrue);
    await session.stop();
    await session.dispose();

    expect(calls, 0);
  });

  test('native playback promotion failure stays inactive', () async {
    final calls = <String>[];
    final session = VoicePlaybackForegroundSession(
      android: true,
      invoke: (method) async {
        calls.add(method);
        return false;
      },
    );

    expect(await session.canStart(), isFalse);
    expect(await session.start(), isFalse);
    expect(session.active, isFalse);
    await session.stop();

    expect(calls, contains('stop'));
  });

  test('stop invalidates a late service start result', () async {
    final ready = Completer<bool>();
    final calls = <String>[];
    final session = VoicePlaybackForegroundSession(
      android: true,
      invoke: (method) {
        calls.add(method);
        return method == 'start' ? ready.future : Future.value(true);
      },
    );

    final starting = session.start();
    await session.stop();
    ready.complete(true);

    expect(await starting, isFalse);
    expect(session.active, isFalse);
    expect(calls, ['start', 'stop']);
  });

  test('dispose clears the service and blocks new starts', () async {
    final calls = <String>[];
    final session = VoicePlaybackForegroundSession(
      android: true,
      invoke: (method) async {
        calls.add(method);
        return true;
      },
    );

    expect(await session.start(), isTrue);
    await session.dispose();
    expect(await session.canStart(), isFalse);
    expect(await session.start(), isFalse);
    expect(calls, ['start', 'stop']);
  });
}
