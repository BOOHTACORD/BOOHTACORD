import 'dart:async';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/cancelled.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/driver.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/publish_capture.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/update.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../screen_adaptation/native_tracks.dart';
import 'confirmed_dimensions_test.dart' show Media, snapshot;

class CaptureTrack extends FixtureTrack {
  @override
  final mediaStreamTrack = Media();
}

class Participant extends FixtureParticipant {
  int publishes = 0, updates = 0;
  VideoPublishOptions? received;
  @override
  Future<LocalTrackPublication<LocalVideoTrack>> publishVideoTrack(
    LocalVideoTrack track, {
    VideoPublishOptions? publishOptions,
  }) async {
    publishes++;
    received = publishOptions;
    return FixturePublication(track, 'owned');
  }

  @override
  Future<LocalTrackPublication<LocalVideoTrack>?> updateScreenShareTrackProfile(
    LocalVideoTrack track, {
    required VideoPublishOptions publishOptions,
    required bool Function() isCurrent,
  }) async {
    expect(isCurrent(), true);
    updates++;
    received = publishOptions;
    return FixturePublication(track, 'owned');
  }
}

class RecordingDriver implements ScreenShareDriver {
  final track = CaptureTrack();
  int publishes = 0, discards = 0;
  VideoDimensions? received;
  @override
  Future<void> prepare(bool Function() active) async {}
  @override
  Future<LocalVideoTrack> capture(ScreenShareCaptureOptions options) async =>
      track;
  @override
  Future<void> publish(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
  ) async {
    publishes++;
    received = dimensions;
    throw const ScreenCaptureCancelled();
  }

  @override
  Future<void> discard(Room room, LocalVideoTrack track) async {
    discards++;
  }

  @override
  Future<void> disableBackground() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('FlutterWebRTC.Method');
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  void bridge(Future<Object?> Function() read) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'mediaStreamTrackGetCaptureSnapshot') {
            return read();
          }
          return null;
        });
  }

  test(
    'lifecycle passes actual Mac dimensions, not supplied preview',
    () async {
      var queries = 0;
      bridge(() async {
        queries++;
        return snapshot();
      });
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final room = FixtureRoom(),
          scope = SessionScope(),
          driver = RecordingDriver();
      final owner = ScreenShareController(
        api,
        scope,
        readRoom: () => room,
        voiceReady: () => true,
        driver: driver,
      );
      await owner.publishCapture(
        room,
        scope.capture(),
        0,
        'owned',
        const VideoDimensions(999, 999),
        false,
      );
      expect(queries, 1);
      expect(driver.publishes, 1);
      expect(driver.received!.width, 1920);
      expect(driver.received!.height, 1246);
      expect(driver.discards, 1);
      owner.dispose();
      api.transport.raw.close();
    },
  );
  test('unavailable Mac snapshot ignores raw preview dimensions', () async {
    bridge(() async => {'schema_version': 1, 'status': 'unavailable'});
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    final room = FixtureRoom(),
        scope = SessionScope(),
        driver = RecordingDriver();
    final owner = ScreenShareController(
      api,
      scope,
      readRoom: () => room,
      voiceReady: () => true,
      driver: driver,
    );
    await owner.publishCapture(
      room,
      scope.capture(),
      0,
      'owned',
      const VideoDimensions(999, 999),
      false,
    );
    expect(driver.received, isNull);
    owner.dispose();
    api.transport.raw.close();
  });
  test(
    'stop during native dimension await discards capture before publish',
    () async {
      final pending = Completer<Object?>(), called = Completer<void>();
      bridge(() {
        called.complete();
        return pending.future;
      });
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final room = FixtureRoom(),
          scope = SessionScope(),
          driver = RecordingDriver();
      final owner = ScreenShareController(
        api,
        scope,
        readRoom: () => room,
        voiceReady: () => true,
        driver: driver,
      );
      final work = owner.publishCapture(
        room,
        scope.capture(),
        0,
        'owned',
        null,
        false,
      );
      await called.future;
      owner.revision++;
      pending.complete(snapshot());
      await work;
      expect(driver.publishes, 0);
      expect(driver.discards, 1);
      owner.dispose();
      api.transport.raw.close();
    },
  );
  test(
    'actual Mac driver consumes verified capture dims for encoded both-bounds',
    () async {
      final room = FixtureRoom(), participant = Participant();
      room.participant = participant;
      await NativeScreenShareDriver().publish(
        room,
        CaptureTrack(),
        const ScreenShareQuality(resolution: 1080, frameRate: 60),
        const VideoDimensions(1920, 1246),
      );
      final scale =
          participant.received!.screenShareEncoding!.scaleResolutionDownBy!;
      expect(participant.publishes, 1);
      expect(1920 ~/ scale, 1662);
      expect(1246 ~/ scale, 1078);
    },
  );
  test(
    'profile update reads actual Mac dimensions and caps both encoded axes',
    () async {
      bridge(() async => snapshot());
      final room = FixtureRoom(), participant = Participant();
      room.participant = participant;
      final track = CaptureTrack()
        ..lastPublishOptions = const ScreenShareQuality(
          resolution: 1080,
          frameRate: 60,
        ).publishOptions(simulcast: false);
      expect(
        await updateScreenShareProfile(
          room,
          track,
          const ScreenShareQuality(resolution: 1080, frameRate: 60),
          const VideoDimensions(999, 999),
          () => true,
        ),
        true,
      );
      final scale =
          participant.received!.screenShareEncoding!.scaleResolutionDownBy!;
      expect(participant.updates, 1);
      expect(1920 ~/ scale, 1662);
      expect(1246 ~/ scale, 1078);
    },
  );
  test(
    'stale owner during profile dimension read never reaches SDK update',
    () async {
      final pending = Completer<Object?>(), called = Completer<void>();
      var current = true;
      bridge(() {
        called.complete();
        return pending.future;
      });
      final room = FixtureRoom(), participant = Participant();
      room.participant = participant;
      final track = CaptureTrack()
        ..lastPublishOptions = const ScreenShareQuality(
          resolution: 1080,
          frameRate: 60,
        ).publishOptions(simulcast: false);
      final work = updateScreenShareProfile(
        room,
        track,
        const ScreenShareQuality(resolution: 1080, frameRate: 60),
        null,
        () => current,
      );
      await called.future;
      current = false;
      pending.complete(snapshot());
      expect(await work, false);
      expect(participant.updates, 0);
    },
  );
}
