import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/screen_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('looks up thumbnails by LiveKit participant identity', () {
    final thumbnail = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
    final thumbnails = {'voice-lease-123': thumbnail};

    expect(
      screenThumbnailForIdentity(thumbnails, 'voice-lease-123'),
      same(thumbnail),
    );
    expect(screenThumbnailForIdentity(thumbnails, null), isNull);
    expect(screenThumbnailForIdentity(thumbnails, 'unknown'), isNull);
  });

  test('compresses a captured frame to a bounded JPEG preview', () {
    final source = image.Image(width: 640, height: 360);
    final png = Uint8List.fromList(image.encodePng(source));
    final thumbnail = encodeScreenThumbnail(png);
    expect(thumbnail, isNotNull);
    expect(thumbnail!.length, lessThanOrEqualTo(14 * 1024));
    final decoded = image.decodeJpg(thumbnail);
    expect(decoded?.width, 480);
    expect(decoded?.height, 270);
  });

  test('retries the first preview quickly and refreshes successful previews every 30 seconds', () {
    expect(
      screenThumbnailCaptureDelay(
        hasCapturedFirstFrame: false,
        initialFailureCount: 0,
      ),
      const Duration(seconds: 1),
    );
    expect(
      screenThumbnailCaptureDelay(
        hasCapturedFirstFrame: false,
        initialFailureCount: 9,
      ),
      const Duration(seconds: 1),
    );
    expect(
      screenThumbnailCaptureDelay(
        hasCapturedFirstFrame: false,
        initialFailureCount: 10,
      ),
      const Duration(seconds: 30),
    );
    expect(
      screenThumbnailCaptureDelay(
        hasCapturedFirstFrame: true,
        initialFailureCount: 0,
      ),
      const Duration(seconds: 30),
    );
  });

  test('rejects malformed JPEG previews', () {
    expect(validScreenThumbnail(Uint8List.fromList([1, 2, 3])), isFalse);
    expect(validScreenThumbnail(Uint8List(15 * 1024)), isFalse);
  });
}
