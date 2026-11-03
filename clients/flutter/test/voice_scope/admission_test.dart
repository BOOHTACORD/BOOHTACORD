import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

import 'api.dart';

import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'matches the web ICE deadline and enables initial subscriptions',
    () async {
      final h = VoiceHarness();
      addTearDown(h.dispose);
      h.api.credential.complete(('lease', credential));

      final joining = h.owner.joinVoice(channel, listenerOnly: true);
      await h.room.connectStarted.future;

      expect(h.room.receivedConnectOptions?.autoSubscribe, isTrue);
      expect(
        h.room.receivedConnectOptions?.timeouts.connection,
        const Duration(seconds: 20),
      );
      expect(
        h.room.receivedConnectOptions?.timeouts.peerConnection,
        const Duration(seconds: 20),
      );

      h.room.connecting.complete();
      await joining;
    },
  );

  test('logout during credential request prevents Room creation', () async {
    final h = VoiceHarness();
    addTearDown(h.dispose);
    final joining = h.owner.joinVoice(channel);
    await Future<void>.delayed(Duration.zero);
    h.scope.close();
    await h.owner.leaveVoice();
    h.api.credential.complete(('lease', credential));
    await joining;
    expect(h.created, 0);
    expect(h.owner.room, isNull);
    expect(h.owner.voicePhase, VoicePhase.idle);
    expect(h.error, isNull);
  });
  test('revocation during connect cannot enable the microphone', () async {
    final h = VoiceHarness();
    addTearDown(h.dispose);
    h.api.credential.complete(('lease', credential));
    final joining = h.owner.joinVoice(channel);
    await Future<void>.delayed(Duration.zero);
    expect(h.room.connectCalled, isTrue);
    h.owner.dispatchVoiceRevocation({'lease_id': 'lease', 'reason': 'KICK'});
    h.room.connecting.complete();
    await joining;
    expect(h.room.localParticipant.enabled, isEmpty);
    expect(h.room.disconnected, greaterThan(0));
    expect(h.owner.room, isNull);
    expect(h.owner.voicePhase, VoicePhase.error);
    expect(h.error, 'Администратор отключил вас от голосового канала.');
  });
  test('a late connected room is disconnected after logout', () async {
    final h = VoiceHarness();
    addTearDown(h.dispose);
    h.api.credential.complete(('lease', credential));
    final joining = h.owner.joinVoice(channel);
    await Future<void>.delayed(Duration.zero);
    h.scope.close();
    await h.owner.leaveVoice();
    final disconnectedAtLogout = h.room.disconnected;
    h.room.connecting.complete();
    await joining;
    expect(h.room.disconnected, greaterThan(disconnectedAtLogout));
    expect(h.owner.voicePhase, VoicePhase.idle);
    expect(h.room.localParticipant.enabled, isEmpty);
  });

  test('refreshes audio devices after a muted voice connection', () async {
    final h = VoiceHarness();
    addTearDown(h.dispose);
    h.enumeratedDevices = const [
      MediaDevice('default', 'System microphone', 'audioinput', null),
      MediaDevice('default-output', 'System output', 'audiooutput', null),
    ];
    await h.audio.refreshAudioDevices();
    expect(h.audio.audioInputDevices.single.deviceId, 'default');

    h.enumeratedDevices = const [
      MediaDevice('default', 'System microphone', 'audioinput', null),
      MediaDevice('usb-mic', 'USB microphone', 'audioinput', null),
      MediaDevice('default-output', 'System output', 'audiooutput', null),
      MediaDevice('usb-headset', 'USB headset', 'audiooutput', null),
    ];
    expect(h.audio.audioInputDevices.single.deviceId, 'default');
    expect(h.audio.audioOutputDevices.single.deviceId, 'default-output');
    h.api.credential.complete(('lease', credential));
    final joining = h.owner.joinVoice(channel, listenerOnly: true);
    await Future<void>.delayed(Duration.zero);
    expect(h.room.connectCalled, isTrue);
    h.room.connecting.complete();
    await joining;

    expect(
      h.audio.audioInputDevices.map((device) => device.deviceId),
      containsAll(['default', 'usb-mic']),
    );
    expect(
      h.audio.audioOutputDevices.map((device) => device.deviceId),
      containsAll(['default-output', 'usb-headset']),
    );
    expect(h.room.localParticipant.enabled, isEmpty);
  });
}
