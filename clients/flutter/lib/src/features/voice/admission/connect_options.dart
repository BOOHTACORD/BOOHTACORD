import 'package:livekit_client/livekit_client.dart';

const _voiceMediaConnectionDeadline = Duration(seconds: 20);

// LiveKit's subscriber-primary handshake needs an initial subscription before
// Room.connect resolves. syncRemoteVoiceSubscriptions drops every eager
// non-microphone subscription immediately after that handshake. The longer
// ICE deadline matches the Web client's voice admission window.
ConnectOptions voiceConnectOptions() {
  final defaults = Timeouts.defaultTimeouts;
  return ConnectOptions(
    autoSubscribe: true,
    timeouts: Timeouts(
      connection: _voiceMediaConnectionDeadline,
      debounce: defaults.debounce,
      publish: defaults.publish,
      subscribe: defaults.subscribe,
      peerConnection: _voiceMediaConnectionDeadline,
      iceRestart: defaults.iceRestart,
    ),
  );
}
