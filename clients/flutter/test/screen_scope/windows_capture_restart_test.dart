import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';

import 'fakes.dart';
import 'quality_fakes.dart';
import 'windows_restart_fakes.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  const high = ScreenShareQuality(resolution: 720, frameRate: 60);
  test('automatic FPS recapture retains the user quality ceiling', () async {
    final driver = WindowsRestartDriver();
    final owner = qualityOwner(driver, WindowsSourceTrack())
      ..quality = high
      ..userQualityCeiling = high
      ..manualQualityRevision = 7;
    addTearDown(owner.dispose);
    driver.captured.complete(FakeScreenTrack());
    await owner.updateScreenShareQuality(
      ScreenShareQuality.balanced,
      fromSupervisor: true,
    );
    expect(owner.phase, ScreenSharePhase.sharing);
    expect(owner.quality, ScreenShareQuality.balanced);
    expect(owner.userQualityCeiling, high);
    expect(owner.manualQualityRevision, 7);
  });
  test(
    'Windows FPS recaptures the same source with screen audio and new FPS',
    () async {
      final driver = WindowsRestartDriver();
      final previous = WindowsSourceTrack();
      final next = FakeScreenTrack();
      final owner = qualityOwner(driver, previous)
        ..quality = ScreenShareQuality.balanced;
      addTearDown(owner.dispose);
      driver.captured.complete(next);
      await owner.updateScreenShareQuality(high);
      expect(driver.stopCalls, 1);
      expect(previous.stopCalls, greaterThanOrEqualTo(1));
      expect(driver.captureOptions!.deviceId, 'owned-window');
      expect(driver.captureOptions!.captureScreenAudio, isTrue);
      expect(driver.captureOptions!.maxFrameRate, 60);
      expect(owner.activeTrack, same(next));
      expect(owner.quality, high);
      expect(owner.phase, ScreenSharePhase.sharing);
      expect(owner.captureRestartRequired, isFalse);
      expect(owner.error, isNull);
    },
  );
  test(
    'explicit stop during Windows recapture cleanup prevents a restart',
    () async {
      final driver = WindowsRestartDriver()..stopGate = Completer<void>();
      final owner = qualityOwner(driver, WindowsSourceTrack());
      addTearDown(owner.dispose);
      final update = owner.updateScreenShareQuality(high);
      await driver.enteredStop.future.timeout(const Duration(seconds: 2));
      final stop = owner.stopScreenShare();
      driver.stopGate!.complete();
      await Future.wait([update, stop]);
      expect(driver.captureOptions, isNull);
      expect(owner.activeTrack, isNull);
      expect(owner.phase, ScreenSharePhase.idle);
    },
  );
  test(
    'room replacement during cleanup prevents recapture in another room',
    () async {
      final driver = WindowsRestartDriver()..stopGate = Completer<void>();
      var room = FakeScreenRoom();
      final owner = qualityOwner(
        driver,
        WindowsSourceTrack(),
        readRoom: () => room,
      );
      addTearDown(owner.dispose);
      final update = owner.updateScreenShareQuality(high);
      await driver.enteredStop.future.timeout(const Duration(seconds: 2));
      room = FakeScreenRoom();
      driver.stopGate!.complete();
      await update;
      expect(driver.captureOptions, isNull);
      expect(owner.activeTrack, isNull);
    },
  );
}
