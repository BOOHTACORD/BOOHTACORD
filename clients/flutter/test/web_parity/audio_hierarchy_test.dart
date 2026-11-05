import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/audio_settings_screen/component.dart';

void main() {
  testWidgets('common audio controls stay visible beside diagnostics', (
    t,
  ) async {
    final state = AppState(ApiClient());
    addTearDown(state.dispose);
    await t.pumpWidget(
      MaterialApp(
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
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Автоматическая регулировка усиления'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Автоматическая регулировка усиления'), findsOneWidget);
    expect(find.text('Подавление эха'), findsOneWidget);
    final control = t.element(find.text('Подавление эха'));
    await t.scrollUntilVisible(
      find.text('Диагностика качества голоса'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    final diagnostics = find.text('Диагностика качества голоса');
    await t.ensureVisible(diagnostics);
    await t.pumpAndSettle();
    await t.tap(diagnostics.hitTestable());
    await t.pumpAndSettle();
    expect(find.text('Профиль следующего подключения'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Подавление эха'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(control.mounted, true);
    expect(state.audioProcessing, isNotNull);
  });
}
