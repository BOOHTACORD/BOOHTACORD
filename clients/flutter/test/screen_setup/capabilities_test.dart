import 'package:boohtacord_desktop/src/features/screen/capabilities/preflight.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native screen audio is available on every shipped native target', () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      final value = ScreenPreflight.detect(platform: platform);
      expect(value.captureConfigured, isTrue);
      expect(value.videoLabel, contains('при запуске'));
      expect(value.captureAudioConfigured, isTrue);
      expect(value.audioLabel, isNot(contains('не публикуется')));
      expect(value.viewerLabel, contains('остаются доступны'));
    }
  });
  test('native inventory failure disables capture while viewer and voice stay available', () {
    final value = ScreenPreflight.detect(
      platform: TargetPlatform.windows,
      selecting: true,
      sourceError: true,
    );
    expect(value.captureConfigured, isFalse);
    expect(value.videoLabel, contains('недоступен'));
    expect(value.viewerLabel, contains('остаются доступны'));
  });
  test(
    'unknown targets and unshipped Flutter web do not claim native capture',
    () {
      expect(
        ScreenPreflight.detect(platform: TargetPlatform.fuchsia)
            .captureConfigured,
        isFalse,
      );
      expect(
        ScreenPreflight.detect(
          platform: TargetPlatform.windows,
          web: true,
        ).captureConfigured,
        isFalse,
      );
    },
  );
}
