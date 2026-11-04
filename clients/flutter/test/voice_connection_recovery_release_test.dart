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
  testWidgets('own voluntary release does not cancel unexpected-disconnect recovery', (tester) async {
    const user = SessionUser(accountId: 'account-1', role: 'MEMBER');
    final harness = VoiceHarness(account: user);
    addTearDown(harness.dispose);
    harness.owner.room = harness.room;
    harness.owner.leaseId = 'old-lease';
    harness.owner.voiceChannel = channel;
    harness.owner.voicePhase = VoicePhase.listener;
    harness.api.onRelease = (lease) async {
      await harness.owner.dispatchVoiceRevocation({
        'lease_id': lease,
        'reason': 'VOLUNTARY_LEAVE',
      });
    };
    await harness.owner.handleUnexpectedVoiceDisconnect(
      harness.room,
      RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded),
    );
    expect(harness.owner.voiceRecoveryActive, isTrue);
    expect(harness.owner.disconnect.notice?.source, isNot('server'));
    await harness.owner.dispatchVoiceRevocation({
      'lease_id': 'old-lease',
      'reason': 'VOLUNTARY_LEAVE',
    });
    expect(harness.owner.voiceRecoveryActive, isTrue);
    harness.owner.cancelVoiceRecovery();
  });

  testWidgets('failed recovery admission releases its lease without cancelling retry', (tester) async {
    const user = SessionUser(accountId: 'account-1', role: 'MEMBER');
    final harness = VoiceHarness(account: user);
    addTearDown(harness.dispose);
    harness.owner.room = harness.room;
    harness.owner.leaseId = 'old-lease';
    harness.owner.voiceChannel = channel;
    harness.owner.voicePhase = VoicePhase.listener;
    harness.api.onRelease = (lease) => harness.owner.dispatchVoiceRevocation({
      'lease_id': lease, 'reason': 'VOLUNTARY_LEAVE',
    });
    await harness.owner.handleUnexpectedVoiceDisconnect(
      harness.room,
      RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded),
    );
    await tester.pump(const Duration(seconds: 1));
    harness.api.credential.complete(('new-lease', credential));
    for (var i = 0; i < 10 && !harness.room.connectCalled; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(harness.room.connectCalled, isTrue);
    harness.room.connecting.completeError(StateError('test media outage'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(harness.owner.voiceRecoveryActive, isTrue);
    expect(harness.owner.disconnect.notice?.source, isNot('server'));
    harness.owner.cancelVoiceRecovery();
  });
}
