import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'fakes.dart';

void main() {
  test(
    'system projection stop clears local share state and background service',
    () async {
      final driver = DelayedScreenDriver();
      final room = FakeScreenRoom();
      final owner = ScreenShareController(
        ApiClient(),
        SessionScope(),
        readRoom: () => room,
        voiceReady: () => true,
        driver: driver,
      );
      addTearDown(owner.dispose);
      final track = FakeScreenTrack();
      owner.activeTrack = track;
      owner.phase = ScreenSharePhase.sharing;
      owner.thumbnails['local'] = Uint8List.fromList([1]);

      owner.unpublished(room, track);
      await owner.closing;

      expect(owner.activeTrack, isNull);
      expect(owner.phase, ScreenSharePhase.idle);
      expect(owner.error, isNull);
      expect(owner.thumbnails, isEmpty);
      expect(driver.stopCalls, 0);
      expect(driver.backgroundDisableCalls, 1);

      owner.unpublished(room, track);
      await owner.closing;
      expect(driver.backgroundDisableCalls, 1);
    },
  );

  test(
    'capture arriving after stop is discarded without publication',
    () async {
      final driver = DelayedScreenDriver();
      final room = FakeScreenRoom();
      final owner = ScreenShareController(
        ApiClient(),
        SessionScope(),
        readRoom: () => room,
        voiceReady: () => true,
        driver: driver,
      );
      addTearDown(owner.dispose);
      final start = owner.startScreenShare();
      await Future<void>.delayed(Duration.zero);
      final stop = owner.stopScreenShare();
      final track = FakeScreenTrack();
      driver.captured.complete(track);
      await Future.wait([start, stop]);
      expect(driver.published, 0);
      expect(driver.stopped, contains(track));
      expect(owner.phase, ScreenSharePhase.idle);
      expect(owner.error, isNull);
    },
  );

  test('screen-audio choice reaches the native capture options', () async {
    final driver = DelayedScreenDriver();
    final room = FakeScreenRoom();
    final owner = ScreenShareController(
      ApiClient(),
      SessionScope(),
      readRoom: () => room,
      voiceReady: () => true,
      driver: driver,
    );
    addTearDown(owner.dispose);
    final track = FakeScreenTrack();
    driver.captured.complete(track);

    await owner.startScreenShare(captureScreenAudio: true);

    expect(driver.captureOptions?.captureScreenAudio, isTrue);
  });

  test('logout during publication removes only that attempt track', () async {
    final scope = SessionScope();
    final driver = DelayedScreenDriver()..publication = Completer<void>();
    final room = FakeScreenRoom();
    final owner = ScreenShareController(
      ApiClient(),
      scope,
      readRoom: () => room,
      voiceReady: () => true,
      driver: driver,
    );
    addTearDown(owner.dispose);
    final track = FakeScreenTrack();
    driver.captured.complete(track);
    final start = owner.startScreenShare();
    await Future<void>.delayed(Duration.zero);
    expect(driver.published, 1);
    scope.close();
    final stop = owner.stopScreenShare();
    driver.publication!.complete();
    await Future.wait([start, stop]);
    expect(driver.removed, [track]);
    expect(owner.phase, ScreenSharePhase.idle);
    expect(owner.error, isNull);
  });
}
