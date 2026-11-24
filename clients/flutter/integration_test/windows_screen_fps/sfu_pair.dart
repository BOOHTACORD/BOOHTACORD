import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/driver.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';

import 'sample.dart';
import 'token.dart';

import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class SfuFpsPair {
  SfuFpsPair(
    this.publisher,
    this.viewer,
    this.owner,
    this.remote,
    this.renderer,
    this.listener,
    this.expectRemote,
  );
  final Room publisher, viewer;
  final ScreenShareController owner;
  LocalVideoTrack get local => owner.activeTrack!;
  final Future<RemoteVideoTrack> Function() expectRemote;
  RemoteVideoTrack remote;
  final rtc.RTCVideoRenderer renderer;
  final EventsListener<RoomEvent> listener;

  static Future<SfuFpsPair> create(
    LocalVideoTrack track,
    ScreenShareQuality quality,
    String url,
  ) async {
    configureOwnedFpsSfu(url);
    const options = RoomOptions(adaptiveStream: false, dynacast: false);
    final publisher = Room(roomOptions: options),
        viewer = Room(roomOptions: options);
    var ready = Completer<RemoteVideoTrack>();
    final listener = viewer.createListener()
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is RemoteVideoTrack && !ready.isCompleted) {
          ready.complete(event.track as RemoteVideoTrack);
        }
      });
    final renderer = rtc.RTCVideoRenderer();
    try {
      await renderer.initialize();
      await viewer.connect(url, ownedFpsToken('fps-viewer'));
      await publisher.connect(url, ownedFpsToken('fps-sender'));
      await NativeScreenShareDriver().publish(publisher, track, quality, null);
      final remote = await ready.future.timeout(const Duration(seconds: 20));
      renderer.srcObject = remote.mediaStream;
      final owner =
          ScreenShareController(
              ApiClient(),
              SessionScope(),
              readRoom: () => publisher,
              voiceReady: () =>
                  publisher.connectionState == ConnectionState.connected,
            )
            ..activeTrack = track
            ..quality = quality
            ..phase = ScreenSharePhase.sharing;
      return SfuFpsPair(
        publisher,
        viewer,
        owner,
        remote,
        renderer,
        listener,
        () {
          ready = Completer<RemoteVideoTrack>();
          return ready.future;
        },
      );
    } catch (_) {
      await listener.dispose();
      await publisher.dispose();
      await viewer.dispose();
      await renderer.dispose();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> measure(int fps) => measureReaders(
    () async => reportCounters(await local.sender!.getStats()),
    () async => reportCounters(await remote.receiver!.getStats()),
    fps,
  );

  Future<void> changeProfile(ScreenShareQuality quality) async {
    final pending = expectRemote();
    await owner.updateScreenShareQuality(quality);
    if (owner.phase != ScreenSharePhase.sharing || owner.quality != quality) {
      throw StateError(
        'Controller did not apply the requested capture profile',
      );
    }
    remote = await pending.timeout(const Duration(seconds: 20));
    renderer.srcObject = remote.mediaStream;
  }

  Future<void> close() async {
    await owner.stopScreenShare();
    owner.dispose();
    await listener.dispose();
    await publisher.disconnect();
    await viewer.disconnect();
    await publisher.dispose();
    await viewer.dispose();
    await renderer.dispose();
  }
}
