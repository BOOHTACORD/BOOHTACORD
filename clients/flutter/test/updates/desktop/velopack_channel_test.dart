import 'package:boohtacord_desktop/src/features/updates/desktop/artifact.dart';
import 'package:boohtacord_desktop/src/features/updates/desktop/velopack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beta native feed is separate from the stable feed', () {
    expect(velopackFeedFileName('beta'), 'releases.beta.json');
    expect(velopackFeedFileName('stable'), 'releases.stable.json');
  });
  test('a channel cannot select an arbitrary local feed path', () {
    for (final channel in [
      '../stable',
      '/tmp/feed',
      'beta/stable',
      'preview',
      '',
    ]) {
      expect(
        () => velopackFeedFileName(channel),
        throwsA(
          isA<ArtifactFailure>().having(
            (e) => e.code,
            'code',
            'native_channel',
          ),
        ),
      );
    }
  });
}
