import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_playback/queue.dart';
import 'package:boohtacord_desktop/src/services/sound_engine_lease.dart';

void main() {
  test('keeps one pending cue and drops the old account after clear', () async {
    final wait = Completer<void>(), calls = <String>[];
    final queue = NativeSoundQueue((_) => true, (_) async => Uint8List(1), (
      kind,
      bytes,
      current,
    ) async {
      if (!current()) return;
      calls.add(kind);
      await wait.future;
    }, () {});
    queue.submit('joined');
    await Future<void>.delayed(Duration.zero);
    queue.submit('left');
    queue.submit('started');
    expect(calls, ['joined']);
    queue.clear();
    wait.complete();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['joined']);
  });
  test('custom decode failure plays exactly one default', () async {
    final played = <bool>[];
    final queue = NativeSoundQueue((_) => true, (_) async => Uint8List(1), (
      kind,
      bytes,
      current,
    ) async {
      played.add(bytes != null);
      if (bytes != null) throw const FormatException();
    }, () {});
    queue.submit('joined', custom: 'id');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(played, [true, false]);
  });
  test('native engine ownership is exclusive and release is idempotent', () {
    final release = SoundEngineLease.acquire()!;
    expect(SoundEngineLease.acquire(), isNull);
    release();
    final next = SoundEngineLease.acquire()!;
    release();
    expect(SoundEngineLease.acquire(), isNull);
    next();
  });
}
