import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:boohtacord_desktop/src/features/screen/capture/driver.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/macos_policy.dart';

void main() {
  test(
    'macOS capture rollout is independent and preserves baseline default',
    () {
      final baseline = nativeScreenCaptureOptions(
        const ScreenShareCaptureOptions(),
        TargetPlatform.macOS,
      );
      expect(baseline.captureEngine, 'baseline');
      final candidate = nativeScreenCaptureOptions(
        const ScreenShareCaptureOptions(captureEngine: 'screen_capture_kit'),
        TargetPlatform.macOS,
      );
      expect(candidate.captureEngine, 'screen_capture_kit');
      expect(
        nativeScreenCaptureOptions(
          const ScreenShareCaptureOptions(),
          TargetPlatform.android,
        ).captureEngine,
        isNull,
      );
      expect(() => macOSCaptureEngine(value: 'other'), throwsArgumentError);
    },
  );
  test(
    'iOS screen-audio capture selects the ReplayKit broadcast extension',
    () {
      const options = ScreenShareCaptureOptions(captureScreenAudio: true);

      final iOS = nativeScreenCaptureOptions(options, TargetPlatform.iOS);
      final android = nativeScreenCaptureOptions(
        options,
        TargetPlatform.android,
      );
      final videoOnly = nativeScreenCaptureOptions(
        const ScreenShareCaptureOptions(),
        TargetPlatform.iOS,
      );

      expect(iOS.useiOSBroadcastExtension, isTrue);
      expect(iOS.captureScreenAudio, isTrue);
      expect(android.useiOSBroadcastExtension, isFalse);
      expect(videoOnly.useiOSBroadcastExtension, isFalse);
    },
  );
}
