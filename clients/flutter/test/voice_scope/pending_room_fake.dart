import 'dart:async';
import 'dart:collection';

import 'package:livekit_client/livekit_client.dart';

class PendingVoiceRoom with EventsEmittable<RoomEvent> implements Room {
  final connecting = Completer<void>();
  final connectStarted = Completer<void>();
  int disconnected = 0;
  bool connectCalled = false;
  ConnectOptions? receivedConnectOptions;
  MediaDevice? selectedOutput;
  @override
  late RoomOptions roomOptions;
  @override
  final PendingMicrophone localParticipant = PendingMicrophone();
  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView({});
  @override
  Future<void> connect(
    String url,
    String token, {
    ConnectOptions? connectOptions,
    RoomOptions? roomOptions,
    FastConnectOptions? fastConnectOptions,
  }) {
    connectCalled = true;
    receivedConnectOptions = connectOptions;
    if (!connectStarted.isCompleted) connectStarted.complete();
    return connecting.future;
  }

  @override
  Future<void> disconnect() async {
    disconnected++;
  }

  void emitEvent(RoomEvent event) {
    // ignore: invalid_use_of_internal_member
    events.emit(event);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PendingMicrophone implements LocalParticipant {
  @override
  LocalTrackPublication? getTrackPublicationBySource(TrackSource source) =>
      null;
  final enabled = <bool>[];
  final capture = Completer<void>();
  final started = Completer<void>();
  @override
  Future<LocalTrackPublication?> setMicrophoneEnabled(
    bool value, {
    AudioCaptureOptions? audioCaptureOptions,
  }) async {
    enabled.add(value);
    if (value) {
      if (!started.isCompleted) started.complete();
      await capture.future;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
