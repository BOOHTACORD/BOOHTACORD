import 'package:boohtacord_desktop/src/features/voice/connection_close/recovery.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'voice_scope/api.dart';
import 'voice_scope/fakes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('transient SDK disconnects may restore the original channel', () {
    for (final reason in [
      DisconnectReason.reconnectAttemptsExceeded,
      DisconnectReason.serverShutdown,
      DisconnectReason.stateMismatch,
      DisconnectReason.disconnected,
      DisconnectReason.signalingConnectionFailure,
      DisconnectReason.signalClose,
      DisconnectReason.connectionTimeout,
      DisconnectReason.mediaFailure,
    ]) {
      expect(shouldRecoverVoiceDisconnect(reason), isTrue, reason: '$reason');
    }
  });

  test('manual leave, administrator removal and identity transfer never auto-rejoin', () {
    for (final reason in [
      DisconnectReason.clientInitiated,
      DisconnectReason.duplicateIdentity,
      DisconnectReason.participantRemoved,
      DisconnectReason.roomDeleted,
      DisconnectReason.roomClosed,
      DisconnectReason.unknown,
    ]) {
      expect(shouldRecoverVoiceDisconnect(reason), isFalse, reason: '$reason');
    }
  });

  testWidgets('long outage reuses the original channel without transferring another lease', (tester) async {
    const user = SessionUser(accountId: 'account-1', role: 'MEMBER');
    final harness = VoiceHarness(account: user);
    addTearDown(harness.dispose);
    harness.owner.room = harness.room;
    harness.owner.leaseId = 'old-lease';
    harness.owner.voiceChannel = channel;
    harness.owner.voicePhase = VoicePhase.listener;
    harness.owner.listenerOnly = true;

    await harness.owner.handleUnexpectedVoiceDisconnect(
      harness.room,
      RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded),
    );
    expect(harness.owner.voiceRecoveryActive, isTrue);
    expect(harness.owner.voiceChannel?.id, 'voice');
    expect(harness.owner.voicePhase, VoicePhase.reconnecting);

    await tester.pump(const Duration(seconds: 1));
    expect(harness.api.requestedVoiceTransfers, [false]);
    harness.api.credential.complete(('new-lease', credential));
    await tester.pump();
    expect(harness.room.connectCalled, isTrue);
    harness.room.connecting.complete();
    await tester.pump();
    await tester.pump();

    expect(harness.owner.voiceRecoveryActive, isFalse);
    expect(harness.owner.voiceChannel?.id, 'voice');
    expect(harness.owner.voicePhase, VoicePhase.listener);
  });

  testWidgets('manual Leave cancels recovery before another credential is requested', (tester) async {
    const user = SessionUser(accountId: 'account-1', role: 'MEMBER');
    final harness = VoiceHarness(account: user);
    addTearDown(harness.dispose);
    harness.owner.room = harness.room;
    harness.owner.leaseId = 'old-lease';
    harness.owner.voiceChannel = channel;
    harness.owner.voicePhase = VoicePhase.listener;

    await harness.owner.handleUnexpectedVoiceDisconnect(
      harness.room,
      RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded),
    );
    expect(harness.owner.voiceRecoveryActive, isTrue);
    await harness.owner.leaveVoice();
    await tester.pump(const Duration(minutes: 5));

    expect(harness.owner.voiceRecoveryActive, isFalse);
    expect(harness.api.requestedVoiceTransfers, isEmpty);
    expect(harness.owner.voicePhase, VoicePhase.idle);
    expect(harness.owner.voiceChannel, isNull);
  });
}
