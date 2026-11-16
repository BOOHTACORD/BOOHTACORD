import 'dart:async';

import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reported native processor errors recover immediately', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final recovered = <String>[];
    final native = NativeNoiseSuppression(
      invoke: (method, _) async {
        if (method == 'getNoiseSuppressionState') {
          return {
            'effectiveEngine': 'unknown',
            'failureReason': 'invalid-audio-samples',
          };
        }
        return {
          'supported': true,
          'effectiveEngine': 'rnnoise',
          'processedFrames': 4,
        };
      },
    );
    await native.prepare(NoiseSuppressionMode.rnnoise);
    native.monitor((reason) async => recovered.add(reason));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(recovered, ['invalid-audio-samples']);
    native.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('non-timeout errors and Windows timeouts recover immediately', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
      debugDefaultTargetPlatformOverride = platform;
      final recovered = <String>[];
      final native = NativeNoiseSuppression(
        invoke: (method, _) async {
          if (method == 'getNoiseSuppressionState') {
            if (platform == TargetPlatform.android) {
              throw StateError('synthetic');
            }
            throw TimeoutException('synthetic');
          }
          return {
            'supported': true,
            'effectiveEngine': 'rnnoise',
            'processedFrames': 4,
          };
        },
      );
      await native.prepare(NoiseSuppressionMode.rnnoise);
      native.monitor((reason) async => recovered.add(reason));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(recovered, ['hook-error']);
      native.dispose();
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
