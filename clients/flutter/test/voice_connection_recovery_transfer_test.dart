import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_scope/api.dart';
import 'voice_scope/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('FlutterWebRTC.Method');
  const audio = MethodChannel('boohtacord/audio_devices');
  testWidgets('transfer revocation cancels recovery after release 503', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audio, (_) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(native, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(audio, null);
    });
    final harness = VoiceHarness(
      account: const SessionUser(accountId: 'account-1', role: 'MEMBER'),
    );
    addTearDown(harness.dispose);
    harness.owner.room = harness.room;
    harness.owner.leaseId = 'old-lease';
    harness.owner.voiceChannel = channel;
    harness.owner.voicePhase = VoicePhase.listener;
    harness.api.onRelease = (_) async =>
        throw const ApiFailure('unavailable', status: 503);
    await harness.owner.handleUnexpectedVoiceDisconnect(
      harness.room,
      RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded),
    );
    expect(harness.owner.voiceRecoveryActive, isTrue);
    await harness.owner.dispatchVoiceRevocation({
      'lease_id': 'old-lease',
      'reason': 'TRANSFER',
    });
    expect(harness.owner.voiceRecoveryActive, isFalse);
    expect(harness.owner.voiceChannel, isNull);
  });
}
