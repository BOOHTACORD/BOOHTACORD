import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../profile/quality.dart';
import 'policy.dart';
import 'native_codec_policy.dart';

VideoPublishOptions nativeScreenPublishPlan(
  ScreenShareQuality quality,
  ScreenMediaRollout rollout,
  TargetPlatform platform, {
  VideoDimensions? sourceDimensions,
  String requestedCodec = const String.fromEnvironment(
    'BOOHTACORD_NATIVE_SCREEN_CODEC',
    defaultValue: 'vp8',
  ),
}) {
  final simulcast =
      rollout.boundedSimulcast &&
      (platform == TargetPlatform.windows || platform == TargetPlatform.macOS);
  final target = quality.parameters.dimensions;
  final lower = VideoParameters(
    dimensions: VideoDimensions(target.width ~/ 2, target.height ~/ 2),
    encoding: VideoEncoding(
      maxFramerate: 15,
      maxBitrate: max(
        150000,
        quality.maxBitrateBps ~/ (4 * (quality.frameRate ~/ 15)),
      ),
    ),
  );
  return quality
      .publishOptions(simulcast: simulcast, sourceDimensions: sourceDimensions)
      .copyWith(
        videoCodec: nativeScreenDefaultCodec(requestedCodec: requestedCodec),
        screenShareSimulcastLayers: simulcast ? [lower] : const [],
        backupVideoCodec: const BackupVideoCodec(
          enabled: false,
          simulcast: false,
        ),
      );
}
