import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';

import 'fakes.dart';
import 'quality_fakes.dart';

void main() {
  test(
    'Android source profile change requires a consented capture restart',
    () async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
      final driver = QualityScreenDriver();
      final track = FakeScreenTrack();
      final owner = qualityOwner(driver, track);
      addTearDown(owner.dispose);
      final previousQuality = owner.quality;

      await owner.updateScreenShareQuality(
        const ScreenShareQuality(resolution: 1080, frameRate: 30),
      );

      expect(owner.captureRestartRequired, isTrue);
      expect(owner.quality, previousQuality);
      expect(owner.activeTrack, same(track));
      expect(owner.phase, ScreenSharePhase.sharing);
      expect(driver.qualityRequests, isEmpty);
      expect(owner.error, contains('остановите демонстрацию'));
    },
  );

  test(
    'Windows unknown source requires explicit restart and preserves profile',
    () async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
      final driver = QualityScreenDriver();
      final track = FakeScreenTrack();
      final owner = qualityOwner(driver, track);
      addTearDown(owner.dispose);
      final previousQuality = owner.quality;

      await owner.updateScreenShareQuality(
        const ScreenShareQuality(resolution: 1080, frameRate: 60),
      );

      expect(owner.captureRestartRequired, isTrue);
      expect(owner.quality, previousQuality);
      expect(owner.activeTrack, same(track));
      expect(owner.phase, ScreenSharePhase.sharing);
      expect(driver.qualityRequests, isEmpty);
      expect(owner.error, contains('остановите демонстрацию'));

      await owner.stopScreenShare();
      expect(owner.captureRestartRequired, isFalse);
      expect(owner.error, isNull);

      final nextTrack = FakeScreenTrack();
      driver.captured.complete(nextTrack);
      await owner.startScreenShare(quality: previousQuality);
      expect(owner.captureRestartRequired, isFalse);
      expect(owner.error, isNull);
      expect(owner.activeTrack, same(nextTrack));
    },
  );

  test(
    'Windows resolution-only profile remains a live publisher update',
    () async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
      final driver = QualityScreenDriver();
      final track = FakeScreenTrack();
      final owner = qualityOwner(driver, track);
      addTearDown(owner.dispose);
      owner.quality = const ScreenShareQuality(resolution: 1080, frameRate: 30);
      const requested = ScreenShareQuality(resolution: 720, frameRate: 30);

      await owner.updateScreenShareQuality(requested);

      expect(owner.captureRestartRequired, isFalse);
      expect(owner.quality, requested);
      expect(owner.activeTrack, same(track));
      expect(driver.qualityRequests, [requested]);
      expect(owner.error, isNull);
    },
  );

  test(
    'macOS resolution change requires restart and keeps current track',
    () async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
      final driver = QualityScreenDriver();
      final track = FakeScreenTrack();
      final owner = qualityOwner(driver, track);
      addTearDown(owner.dispose);
      owner.quality = const ScreenShareQuality(resolution: 1080, frameRate: 30);
      const requested = ScreenShareQuality(resolution: 720, frameRate: 30);

      await owner.updateScreenShareQuality(requested);

      expect(owner.captureRestartRequired, isTrue);
      expect(
        owner.quality,
        const ScreenShareQuality(resolution: 1080, frameRate: 30),
      );
      expect(owner.activeTrack, same(track));
      expect(owner.phase, ScreenSharePhase.sharing);
      expect(driver.qualityRequests, isEmpty);
      expect(owner.error, contains('остановите демонстрацию'));
    },
  );
}
