import 'package:boohtacord_desktop/src/features/voice/background_playback/session.dart';
import 'package:boohtacord_desktop/src/features/voice/background_microphone/session.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../voice_scope/api.dart';
import '../../../voice_scope/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const audioDevices = MethodChannel('boohtacord/audio_devices');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioDevices, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioDevices, null);
  });

  test('listener join starts only playback coverage without microphone FGS', () async {
    final calls = <String>[];
    final microphoneCalls = <String>[];
    final microphone = MicrophoneForegroundSession(
      android: true,
      invoke: (method) async {
        microphoneCalls.add(method);
        return true;
      },
    );
    final playback = VoicePlaybackForegroundSession(
      android: true,
      invoke: (method) async {
        calls.add(method);
        return true;
      },
    );
    final harness = VoiceHarness(
      foreground: microphone,
      playbackForeground: playback,
    );
    addTearDown(harness.dispose);
    harness.api.credential.complete(('lease', credential));

    final joining = harness.owner.joinVoice(channel, listenerOnly: true);
    await harness.room.connectStarted.future;
    harness.room.connecting.complete();
    await joining;

    expect(
      harness.owner.voicePhase,
      VoicePhase.listener,
      reason:
          'failure=${harness.owner.lastVoiceAdmissionFailure}; error=${harness.error}',
    );
    expect(harness.room.localParticipant.enabled, isEmpty);
    expect(microphoneCalls, isEmpty);
    expect(playback.active, isTrue);
    expect(calls, ['canStart', 'start']);
  });

  test(
    'leave stops playback coverage once the user voice session ends',
    () async {
      final calls = <String>[];
      final playback = VoicePlaybackForegroundSession(
        android: true,
        invoke: (method) async {
          calls.add(method);
          return true;
        },
      );
      final harness = VoiceHarness(playbackForeground: playback);
      addTearDown(harness.dispose);
      harness.owner.room = harness.room;
      harness.owner.voicePhase = VoicePhase.listener;
      await playback.start();

      await harness.owner.leaveVoice();

      expect(playback.active, isFalse);
      expect(calls, ['start', 'stop']);
      expect(harness.owner.room, isNull);
    },
  );

  test(
    'unexpected playback service stop warns without background restart',
    () async {
      final calls = <String>[];
      final playback = VoicePlaybackForegroundSession(
        android: true,
        invoke: (method) async {
          calls.add(method);
          return true;
        },
      );
      final harness = VoiceHarness(playbackForeground: playback);
      addTearDown(harness.dispose);
      harness.owner.room = harness.room;
      harness.owner.voicePhase = VoicePhase.listener;
      await playback.start();

      playback.active = false;
      playback.onStopped?.call();

      expect(harness.owner.voicePlaybackBackgroundUnavailable, isTrue);
      expect(calls, ['start']);
    },
  );
}
