import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../capture/plan.dart';
import '../capture/jpeg_source_dimensions.dart' as jpeg_dimensions;
import 'geometry.dart';

class ScreenShareQuality {
  const ScreenShareQuality({required this.resolution, required this.frameRate});

  static const resolutions = [720, 1080, 1440];
  static const frameRates = [15, 30, 60];
  static const _bitratesBps = {
    720: {15: 1_500_000, 30: 2_500_000, 60: 4_000_000},
    1080: {15: 2_500_000, 30: 5_000_000, 60: 8_000_000},
    1440: {15: 5_000_000, 30: 8_000_000, 60: 12_000_000},
  };

  final int resolution;
  final int frameRate;

  /// Reads native desktop preview dimensions without decoding its JPEG pixels.
  static VideoDimensions? sourceDimensionsFromJpeg(Uint8List? bytes) =>
      jpeg_dimensions.sourceDimensionsFromJpeg(bytes);

  int get maxBitrateBps {
    if (!resolutions.contains(resolution) || !frameRates.contains(frameRate)) {
      throw ArgumentError('Некорректный профиль демонстрации.');
    }
    return _bitratesBps[resolution]![frameRate]!;
  }

  /// Legacy display value in kbit/s; contract values and encoders use bit/s.
  int get maxBitrate => maxBitrateBps ~/ 1000;

  String get estimatedBandwidth => maxBitrateBps >= 1000000
      ? '≈ ${(maxBitrateBps / 1000000).toStringAsFixed(maxBitrateBps % 1000000 == 0 ? 0 : 1)} Мбит/с'
      : '≈ ${(maxBitrateBps / 1000).toStringAsFixed(0)} Кбит/с';

  String get trackName => 'screenshare-${resolution}p-${frameRate}fps';

  VideoParameters get parameters => VideoParameters(
    dimensions: switch (resolution) {
      720 => VideoDimensionsPresets.h720_169,
      1080 => VideoDimensionsPresets.h1080_169,
      _ => VideoDimensionsPresets.h1440_169,
    },
    encoding: VideoEncoding(
      maxFramerate: frameRate,
      maxBitrate: maxBitrateBps,
    ),
  );

  // Legacy capture ceiling retained for platforms without a desktop capture plan.
  int get captureFrameRate => 60;

  // Desktop paths use the selected profile when the source is created.
  VideoParameters get captureParameters =>
      const ScreenShareQuality(resolution: 1440, frameRate: 60).parameters;

  ScreenShareCapturePlan capturePlan(TargetPlatform platform) =>
      ScreenShareCapturePlan.forProfile(
        profileParameters: parameters,
        profileMaxFrameRate: frameRate,
        legacyParameters: captureParameters,
        legacyMaxFrameRate: captureFrameRate,
        platform: platform,
      );

  /// Fits both encoded dimensions within the oriented profile bounds without
  /// stretching the capture. Native capture ceilings are a separate policy.
  double scaleResolutionDownBy(VideoDimensions source) =>
      ScreenProfileGeometry.scaleDownBy(source: source, target: parameters.dimensions);

  VideoPublishOptions publishOptions({
    required bool simulcast,
    VideoDimensions? sourceDimensions,
  }) {
    final encoding = parameters.encoding!;
    final scale = sourceDimensions == null
        ? 1.0
        : scaleResolutionDownBy(sourceDimensions);
    return VideoPublishOptions(
      name: trackName,
      screenShareEncoding: encoding.copyWith(scaleResolutionDownBy: scale),
      degradationPreference: DegradationPreference.maintainFramerate,
      simulcast: simulcast,
    );
  }

  static const balanced = ScreenShareQuality(resolution: 720, frameRate: 15);
  static const desktopDefault = ScreenShareQuality(
    resolution: 1080,
    frameRate: 30,
  );

  @override
  bool operator ==(Object other) =>
      other is ScreenShareQuality &&
      resolution == other.resolution &&
      frameRate == other.frameRate;

  @override
  int get hashCode => Object.hash(resolution, frameRate);
}
