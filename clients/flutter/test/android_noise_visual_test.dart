import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:boohtacord_desktop/src/widgets/noise_suppression_settings.dart';
import 'package:boohtacord_desktop/src/theme.dart';

import 'uiux_2026/capture_support.dart';

void main() {
  testWidgets('Android unavailable RNNoise remains selectable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await loadUiuxVisualCaptureFonts();
    const key = ValueKey('android-noise-retry-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: guildTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: NoiseSuppressionSettings(
                processing: const AudioProcessingPreferences(
                  noiseSuppressionMode: NoiseSuppressionMode.rnnoise,
                ),
                runtime: const NativeNoiseSuppressionState(
                  requestedMode: NoiseSuppressionMode.rnnoise,
                  status: 'unsupported',
                  failureReason: 'processor-unavailable',
                ),
                onChanged: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(
      find.byType(DropdownButtonFormField<NoiseSuppressionMode>),
    );
    await tester.pumpAndSettle();
    final menuTheme = Theme.of(tester.element(find.text('RNNoise 0.1').last));
    expect(menuTheme.focusColor.computeLuminance(), lessThan(0.18));
    await captureUiuxBoundary(
      tester,
      find.byKey(key),
      fileName: 'android-noise-retry-menu-390.png',
      pixelRatio: 1,
    );
    expect(find.text('RNNoise 0.1'), findsWidgets);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    debugDefaultTargetPlatformOverride = null;
  });
}
