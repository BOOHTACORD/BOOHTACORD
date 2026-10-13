import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/driver.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';

class FakeScreenRoom implements Room {
  @override
  final LocalParticipant localParticipant = FakeScreenParticipant();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScreenParticipant implements LocalParticipant {
  @override
  String get identity => 'local';
  @override
  ConnectionQuality get connectionQuality => ConnectionQuality.unknown;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMediaStreamTrack implements rtc.MediaStreamTrack {
  @override
  String get id => 'fake-screen-track';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScreenTrack implements LocalVideoTrack {
  int stopCalls = 0;

  @override
  rtc.MediaStreamTrack get mediaStreamTrack => FakeMediaStreamTrack();

  @override
  Future<bool> stop() async {
    stopCalls++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScreenAudioTrack implements LocalAudioTrack {
  int stopCalls = 0;

  @override
  Future<bool> stop() async {
    stopCalls++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DelayedScreenDriver implements ScreenShareDriver {
  final captured = Completer<LocalVideoTrack>();
  Completer<void>? publication;
  ScreenShareCaptureOptions? captureOptions;
  int published = 0;
  int stopCalls = 0;
  int backgroundDisableCalls = 0;
  final stopped = <LocalVideoTrack>[];
  final removed = <LocalVideoTrack>[];
  @override
  Future<void> prepare(bool Function() active) async {}
  @override
  Future<LocalVideoTrack> capture(ScreenShareCaptureOptions options) {
    captureOptions = options;
    return captured.future;
  }

  @override
  Future<void> publish(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
  ) async {
    published++;
    await publication?.future;
  }

  @override
  Future<bool> updateQuality(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
    bool Function() isCurrent,
  ) async => isCurrent();

  @override
  Future<void> discard(Room room, LocalVideoTrack track) async {
    removed.add(track);
    stopped.add(track);
  }

  @override
  Future<void> stop(Room room) async {
    stopCalls++;
  }

  @override
  Future<void> disableBackground() async {
    backgroundDisableCalls++;
  }
}
