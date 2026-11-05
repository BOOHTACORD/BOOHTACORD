import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/audio_settings_screen/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'uiux_2026/capture_support.dart';

const guidanceTitle = 'Музыка становится тише при входе в голосовой канал?';

void main() {
  setUpAll(loadUiuxVisualCaptureFonts);
  setUp(() {
    const recorder = MethodChannel('com.llfbandit.record/messages');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Only creation/disposal occur in these UI tests; audio capture is not exercised.
    messenger.setMockMethodCallHandler(recorder, (call) async {
      if (call.method == 'create' || call.method == 'dispose') {
        return null;
      }
      throw MissingPluginException(
        'Unexpected recorder operation: ${call.method}',
      );
    });
    addTearDown(() => messenger.setMockMethodCallHandler(recorder, null));
  });
  testWidgets(
    'non-Windows audio settings omit Windows system guidance',
    (tester) async {
      final state = AppState(ApiClient());
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          home: Scaffold(
            body: WorkspaceAudioSettingsScreen(
              state: state,
              onBack: () {},
              onCapturePttKey: null,
              capturingPttKey: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final diagnostics = find.text('Диагностика качества голоса');
      await tester.scrollUntilVisible(
        diagnostics,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(guidanceTitle), findsNothing);
      expect(
        find.textContaining('Панель управления → Звук → Связь'),
        findsNothing,
      );
      await tester.ensureVisible(diagnostics);
      await tester.pumpAndSettle();
      await tester.tap(diagnostics.hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Профиль следующего подключения'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );
  for (final profile in [(800.0, 600.0, 1.0), (320.0, 480.0, 2.0)]) {
    testWidgets(
      'Windows audio help and diagnostics remain reachable at ${profile.$1} text ${profile.$3}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(profile.$1, profile.$2);
        addTearDown(tester.view.reset);
        final state = AppState(ApiClient());
        addTearDown(state.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(profile.$1, profile.$2),
                textScaler: TextScaler.linear(profile.$3),
              ),
              child: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                  body: WorkspaceAudioSettingsScreen(
                    state: state,
                    onBack: () {},
                    onCapturePttKey: null,
                    capturingPttKey: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final help = find.text(guidanceTitle);
        await tester.scrollUntilVisible(
          help,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(help, findsOneWidget);
        expect(
          find.textContaining('Панель управления → Звук → Связь').hitTestable(),
          findsNothing,
        );
        await tester.ensureVisible(help);
        await tester.pumpAndSettle();
        if (profile.$1 == 800) {
          await captureUiuxBoundary(
            tester,
            find.byKey(boundary),
            fileName: 'audio-coexistence-windows-collapsed.png',
            pixelRatio: 1,
          );
        }
        await tester.tap(help.hitTestable());
        await tester.pumpAndSettle();
        final guidance = find.textContaining(
          'Панель управления → Звук → Связь',
        );
        expect(guidance, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(help);
        await tester.pumpAndSettle();
        await captureUiuxBoundary(
          tester,
          find.byKey(boundary),
          fileName: profile.$1 == 800
              ? 'audio-coexistence-windows-expanded.png'
              : 'audio-coexistence-windows-large-text.png',
          pixelRatio: 1,
        );
        await tester.tap(help.hitTestable());
        await tester.pumpAndSettle();
        final diagnostics = find.text('Диагностика качества голоса');
        await tester.scrollUntilVisible(
          diagnostics,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(diagnostics);
        await tester.pumpAndSettle();
        await tester.tap(diagnostics.hitTestable());
        await tester.pumpAndSettle();
        expect(find.text('Профиль следующего подключения'), findsOneWidget);
        expect(state.audioProcessing, isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
