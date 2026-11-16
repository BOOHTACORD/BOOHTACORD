import 'dart:async';

import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Android tolerates one transient native state timeout', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var reads = 0;
    final recovered = <String>[];
    final native = NativeNoiseSuppression(
      invoke: (method, _) async {
        if (method == 'getNoiseSuppressionState' && ++reads == 1) {
          throw TimeoutException('synthetic state timeout');
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
    expect(recovered, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(reads, 2);
    expect(native.state.status, 'active');
    expect(recovered, isEmpty);
    native.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android recovers after three consecutive timeouts', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final recovered = <String>[];
    final native = NativeNoiseSuppression(
      invoke: (method, _) async {
        if (method == 'getNoiseSuppressionState') {
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
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(recovered, isEmpty);
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(recovered, ['hook-error']);
    native.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('successful state reads reset the Android timeout streak', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var reads = 0;
    final recovered = <String>[];
    final native = NativeNoiseSuppression(
      invoke: (method, _) async {
        if (method == 'getNoiseSuppressionState' && (++reads).isOdd) {
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
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
    }
    expect(reads, 4);
    expect(recovered, isEmpty);
    native.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
