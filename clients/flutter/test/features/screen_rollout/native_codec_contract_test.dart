import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:boohtacord_desktop/src/features/screen/rollout/policy.dart';
import 'package:boohtacord_desktop/src/features/screen/rollout/publish_plan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  const profiles = [
    ScreenShareQuality(resolution: 720, frameRate: 60),
    ScreenShareQuality(resolution: 1080, frameRate: 60),
    ScreenShareQuality(resolution: 1080, frameRate: 30),
  ];
  for (final platform in TargetPlatform.values) {
    for (final quality in profiles) {
      test(
        'baseline ${platform.name} ${quality.trackName} preserves one VP8 encoder plan',
        () {
          final plan = nativeScreenPublishPlan(
            quality,
            const ScreenMediaRollout(),
            platform,
          );
          expect(plan.videoCodec, 'vp8');
          expect(plan.simulcast, false);
          expect(plan.screenShareSimulcastLayers, isEmpty);
          expect(plan.backupVideoCodec.enabled, false);
          expect(plan.backupVideoCodec.simulcast, false);
          expect(plan.screenShareEncoding!.maxBitrate, quality.maxBitrateBps);
          expect(plan.screenShareEncoding!.maxFramerate, quality.frameRate);
          expect(
            plan.degradationPreference,
            DegradationPreference.maintainFramerate,
          );
        },
      );
    }
  }
  test(
    'metadata and JPEG switches do not silently change native codec topology',
    () {
      const flags = ScreenMediaRollout(descriptor: false, jpegPreview: false);
      final plan = nativeScreenPublishPlan(
        profiles[1],
        flags,
        TargetPlatform.macOS,
      );
      expect(plan.videoCodec, 'vp8');
      expect(plan.simulcast, false);
      expect(plan.backupVideoCodec.enabled, false);
    },
  );
}
