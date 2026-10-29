import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const maxScreenThumbnailBytes = 14 * 1024;
const maxScreenThumbnailWidth = 480;
const maxScreenThumbnailHeight = 320;
const screenThumbnailCaptureInterval = Duration(seconds: 30);
const screenThumbnailInitialRetryInterval = Duration(seconds: 1);
const screenThumbnailInitialRetryLimit = 10;
const _thumbnailScaleFactors = [1.0, 2 / 3, 1 / 2, 1 / 3, 1 / 4, 1 / 5];
const _thumbnailQualities = [82, 74, 66, 60];

Duration screenThumbnailCaptureDelay({
  required bool hasCapturedFirstFrame,
  required int initialFailureCount,
}) =>
    !hasCapturedFirstFrame &&
        initialFailureCount < screenThumbnailInitialRetryLimit
    ? screenThumbnailInitialRetryInterval
    : screenThumbnailCaptureInterval;

enum ScreenThumbnailCaptureResult {
  cancelled,
  captureFailed,
  encodingFailed,
  invalidThumbnail,
  captured,
}

Future<ScreenThumbnailCaptureResult> captureScreenThumbnailFrame({
  required Future<Uint8List> Function() capture,
  required Future<Uint8List?> Function(Uint8List frame) encode,
  required void Function(Uint8List thumbnail) storeLocally,
  required bool Function() isActive,
}) async {
  late final Uint8List frame;
  try {
    frame = await capture();
  } catch (_) {
    return ScreenThumbnailCaptureResult.captureFailed;
  }

  late final Uint8List? thumbnail;
  try {
    thumbnail = await encode(frame);
  } catch (_) {
    return ScreenThumbnailCaptureResult.encodingFailed;
  }

  if (!isActive()) return ScreenThumbnailCaptureResult.cancelled;
  if (thumbnail == null || !validScreenThumbnail(thumbnail)) {
    return ScreenThumbnailCaptureResult.invalidThumbnail;
  }

  storeLocally(thumbnail);
  return ScreenThumbnailCaptureResult.captured;
}

Uint8List? screenThumbnailForIdentity(
  Map<String, Uint8List> thumbnails,
  String? identity,
) => identity == null ? null : thumbnails[identity];

Uint8List? encodeScreenThumbnail(Uint8List frame) {
  final decoded = image.decodeImage(frame);
  if (decoded == null) return null;

  final scale = math.min(
    1.0,
    math.min(
      maxScreenThumbnailWidth / decoded.width,
      maxScreenThumbnailHeight / decoded.height,
    ),
  );
  final boundedWidth = math.max(1, (decoded.width * scale).round());
  final widths = <int>{
    for (final factor in _thumbnailScaleFactors)
      math.max(1, (boundedWidth * factor).round()),
  };

  for (final width in widths) {
    final height = math.max(
      1,
      (decoded.height * width / decoded.width).round(),
    );
    if (width > maxScreenThumbnailWidth || height > maxScreenThumbnailHeight) {
      continue;
    }
    final resized = image.copyResize(decoded, width: width, height: height);
    final qualities = width <= 160 ? const [45] : _thumbnailQualities;
    for (final quality in qualities) {
      final encoded = Uint8List.fromList(
        image.encodeJpg(resized, quality: quality),
      );
      if (validScreenThumbnail(encoded)) return encoded;
    }
  }
  return null;
}

bool validScreenThumbnail(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes.length <= maxScreenThumbnailBytes &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[bytes.length - 2] == 0xff &&
    bytes.last == 0xd9;

/// Serializes native `captureFrame()` calls, which currently share a temporary
/// PNG path inside flutter_webrtc.
class ScreenThumbnailCaptureQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}

bool isCurrentScreenViewerSelection(String? requested, String? selected) =>
    requested == selected;
