import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:boohtacord_desktop/src/features/screen/capture/driver.dart';

void main() {
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
