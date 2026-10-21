import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/audio_settings_screen/component.dart';

void main() {
  testWidgets('advanced audio stays mounted while disclosure changes', (
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
    expect(find.text('Автоматическая регулировка усиления'), findsNothing);
    final section = find.byKey(const PageStorageKey('audio-settings-advanced'));
    await t.scrollUntilVisible(
      section,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Дополнительно'));
    await t.pumpAndSettle();
    expect(find.text('Автоматическая регулировка усиления'), findsOneWidget);
    final element = t.element(find.text('Автоматическая регулировка усиления'));
    await t.scrollUntilVisible(
      section,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Дополнительно'));
    await t.pumpAndSettle();
    expect(element.mounted, true);
    expect(state.audioProcessing, isNotNull);
  });
}
