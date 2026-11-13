import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/native_noise_suppression.dart';
import 'package:boohtacord_desktop/src/widgets/noise_suppression_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget screen({
    bool enable = false,
    NoiseSuppressionMode mode = NoiseSuppressionMode.browser,
  }) => MaterialApp(
    home: Scaffold(
      body: NoiseSuppressionSettings(
        processing: AudioProcessingPreferences(noiseSuppressionMode: mode),
        runtime: const NativeNoiseSuppressionState(),
        allowExperimentalDeepFilter: enable,
        onChanged: (_) async {},
      ),
    ),
  );

  testWidgets('experimental engine is hidden by default', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(screen());
      await tester.tap(
        find.byType(DropdownButtonFormField<NoiseSuppressionMode>),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DeepFilterNet3'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('enabled Windows build offers the engine', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(screen(enable: true));
      await tester.tap(
        find.byType(DropdownButtonFormField<NoiseSuppressionMode>),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DeepFilterNet3'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('selected engine explains resource cost', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        screen(enable: true, mode: NoiseSuppressionMode.deepfilter),
      );
      expect(
        find.textContaining('нагрузку процессора и задержку'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('flag does not enable the Windows engine on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(screen(enable: true));
      await tester.tap(
        find.byType(DropdownButtonFormField<NoiseSuppressionMode>),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DeepFilterNet3'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('unavailable saved selection is retained and labelled', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(screen(mode: NoiseSuppressionMode.deepfilter));
      expect(find.textContaining('DeepFilterNet3'), findsOneWidget);
      await tester.tap(
        find.byType(DropdownButtonFormField<NoiseSuppressionMode>),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('недоступен'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
