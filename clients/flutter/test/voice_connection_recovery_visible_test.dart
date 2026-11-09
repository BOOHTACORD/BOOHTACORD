import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/admission/failure.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_scope/api.dart';
import 'voice_scope/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('FlutterWebRTC.Method');
  const audio = MethodChannel('boohtacord/audio_devices');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audio, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audio, null);
  });

  testWidgets('transient retry never publishes a disconnected channel', (
    tester,
  ) async {
    final harness = VoiceHarness(
      account: const SessionUser(accountId: 'account-1', role: 'MEMBER'),
    );
    addTearDown(harness.dispose);
    harness.owner.voiceChannel = channel;
    harness.owner.voicePhase = VoicePhase.joining;
    harness.owner.voiceRecoveryActive = true;
    await harness.owner.failVoiceAdmission(
      StateError('synthetic media outage'),
      null,
    );
    expect(harness.owner.voiceRecoveryActive, isTrue);
    expect(harness.owner.voicePhase, VoicePhase.reconnecting);
    expect(harness.owner.voiceChannel?.id, channel.id);
    expect(harness.error, isNull);
    harness.owner.cancelVoiceRecovery();
  });

  for (final status in [401, 403, 404, 409]) {
    testWidgets('terminal $status still clears the channel', (tester) async {
      final harness = VoiceHarness(
        account: const SessionUser(accountId: 'account-1', role: 'MEMBER'),
      );
      addTearDown(harness.dispose);
      harness.owner.voiceChannel = channel;
      harness.owner.voicePhase = VoicePhase.joining;
      harness.owner.voiceRecoveryActive = true;
      await harness.owner.failVoiceAdmission(
        ApiFailure('terminal', status: status),
        null,
      );
      expect(harness.owner.voicePhase, VoicePhase.error);
      expect(harness.owner.voiceChannel, isNull);
      expect(harness.error, 'terminal');
      harness.owner.cancelVoiceRecovery();
    });
  }

  testWidgets('ordinary failed join keeps the error behavior', (tester) async {
    final harness = VoiceHarness(
      account: const SessionUser(accountId: 'account-1', role: 'MEMBER'),
    );
    addTearDown(harness.dispose);
    harness.owner.voiceChannel = channel;
    harness.owner.voicePhase = VoicePhase.joining;
    await harness.owner.failVoiceAdmission(StateError('outage'), null);
    expect(harness.owner.voicePhase, VoicePhase.error);
    expect(harness.owner.voiceChannel, isNull);
    expect(harness.error, isNotNull);
  });
}
