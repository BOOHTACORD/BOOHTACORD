import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

class TestAudioTrack implements LocalAudioTrack {
  @override
  AudioCaptureOptions currentOptions = const AudioCaptureOptions();
  @override
  bool muted = false;
  int unmuteCalls = 0;
  final restarts = <AudioCaptureOptions>[];
  Completer<void>? restarted;
  @override
  Future<bool> mute({bool stopOnMute = true}) async {
    muted = true;
    return true;
  }

  @override
  Future<bool> unmute({bool stopOnMute = true}) async {
    muted = false;
    unmuteCalls++;
    return true;
  }

  @override
  Future<void> disable() async {}
  @override
  Future<void> restartTrack([LocalTrackOptions? options]) async {
    currentOptions = options as AudioCaptureOptions;
    restarts.add(currentOptions);
    if (restarted != null && !restarted!.isCompleted) restarted!.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestPublication implements LocalTrackPublication<LocalAudioTrack> {
  TestPublication(this.track);
  @override
  final LocalAudioTrack track;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestParticipant implements LocalParticipant {
  TestParticipant(this.track);
  final LocalAudioTrack track;
  @override
  LocalTrackPublication? getTrackPublicationBySource(TrackSource source) =>
      TestPublication(track);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestRoom implements Room {
  TestRoom(this.localParticipant);
  @override
  final LocalParticipant localParticipant;
  final inputs = <MediaDevice>[];
  Future<void> setAudioInputDevice(MediaDevice device) async {
    inputs.add(device);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
