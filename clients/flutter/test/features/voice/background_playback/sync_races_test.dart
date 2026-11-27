import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/background_playback/session.dart';
import 'package:boohtacord_desktop/src/features/voice/background_playback/sync.dart';

import '../../../voice_scope/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const devices = MethodChannel('boohtacord/audio_devices');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(devices, (_) async => null),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(devices, null),
  );

  test(
    'late failed promotion cannot mark a fresh undeafened session unavailable',
    () async {
      final old = Completer<bool>(), began = Completer<void>();
      var starts = 0;
      final session = VoicePlaybackForegroundSession(
        android: true,
        invoke: (method) {
          if (method == 'start' && starts++ == 0) {
            began.complete();
            return old.future;
          }
          return Future.value(true);
        },
      );
      final h = VoiceHarness(playbackForeground: session);
      addTearDown(h.dispose);
      h.owner.room = h.room;
      final previous = h.owner.syncVoicePlaybackForeground();
      await began.future;
      h.owner.deafened = true;
      await h.owner.syncVoicePlaybackForeground();
      h.owner.deafened = false;
      expect(await h.owner.syncVoicePlaybackForeground(), true);
      old.completeError(StateError('obsolete promotion'));
      expect(await previous, false);
      expect(session.active, true);
      expect(h.owner.voicePlaybackBackgroundUnavailable, false);
    },
  );

  test(
    'late admission denial cannot overwrite a newer successful request',
    () async {
      final old = Completer<bool>(), began = Completer<void>();
      var admissions = 0;
      final session = VoicePlaybackForegroundSession(
        android: true,
        invoke: (method) {
          if (method == 'canStart' && admissions++ == 0) {
            began.complete();
            return old.future;
          }
          return Future.value(true);
        },
      );
      final h = VoiceHarness(playbackForeground: session);
      addTearDown(h.dispose);
      h.owner.room = h.room;
      final previous = h.owner.syncVoicePlaybackForeground();
      await began.future;
      h.owner.deafened = true;
      await h.owner.syncVoicePlaybackForeground();
      h.owner.deafened = false;
      expect(await h.owner.syncVoicePlaybackForeground(), true);
      old.complete(false);
      expect(await previous, false);
      expect(session.active, true);
      expect(h.owner.voicePlaybackBackgroundUnavailable, false);
    },
  );

  test(
    'late deafen stop cannot clear a newer promotion failure notice',
    () async {
      final old = Completer<bool>(), began = Completer<void>();
      var stops = 0;
      final session = VoicePlaybackForegroundSession(
        android: true,
        invoke: (method) {
          if (method == 'stop' && stops++ == 0) {
            began.complete();
            return old.future;
          }
          return Future.value(method == 'canStart' || method == 'stop');
        },
      );
      final h = VoiceHarness(playbackForeground: session);
      addTearDown(h.dispose);
      h.owner.room = h.room;
      h.owner.deafened = true;
      final previous = h.owner.syncVoicePlaybackForeground();
      await began.future;
      h.owner.deafened = false;
      expect(await h.owner.syncVoicePlaybackForeground(), false);
      expect(h.owner.voicePlaybackBackgroundUnavailable, true);
      old.complete(true);
      await previous;
      expect(h.owner.voicePlaybackBackgroundUnavailable, true);
    },
  );
}
