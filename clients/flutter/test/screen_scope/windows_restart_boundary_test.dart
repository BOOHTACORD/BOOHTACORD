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
  test('logout during restart cleanup cannot resurrect capture', () async {
    final driver = WindowsRestartDriver()..stopGate = Completer<void>();
    final owner = qualityOwner(driver, WindowsSourceTrack());
    addTearDown(owner.dispose);
    final operation = owner.updateScreenShareQuality(high);
    await driver.enteredStop.future;
    owner.scope.close();
    driver.stopGate!.complete();
    await operation;
    expect(driver.captureOptions, isNull);
    expect(owner.activeTrack, isNull);
  });
  test(
    'a new explicit source start wins pending automatic recapture',
    () async {
      final driver = WindowsRestartDriver()..stopGate = Completer<void>();
      final owner = qualityOwner(driver, WindowsSourceTrack());
      addTearDown(owner.dispose);
      final operation = owner.updateScreenShareQuality(high);
      await driver.enteredStop.future;
      driver.captured.complete(FakeScreenTrack());
      final explicit = owner.startScreenShare(
        sourceId: 'new-source',
        quality: ScreenShareQuality.desktopDefault,
      );
      driver.stopGate!.complete();
      await Future.wait([operation, explicit]);
      expect(driver.captureOptions!.deviceId, 'new-source');
      expect(driver.captureOptions!.maxFrameRate, 30);
      expect(owner.phase, ScreenSharePhase.sharing);
    },
  );
  test(
    'source loss during recapture leaves an honest retryable error',
    () async {
      final driver = WindowsRestartDriver()
        ..captureFailure = StateError('owned source disappeared');
      final owner = qualityOwner(driver, WindowsSourceTrack());
      addTearDown(owner.dispose);
      await owner.updateScreenShareQuality(high);
      expect(driver.stopCalls, 1);
      expect(owner.activeTrack, isNull);
      expect(owner.phase, ScreenSharePhase.error);
      expect(owner.error, contains('owned source disappeared'));
    },
  );
}
