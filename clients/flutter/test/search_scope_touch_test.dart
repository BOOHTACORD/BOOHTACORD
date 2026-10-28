import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/workspace_search_panel/lifecycle/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'uiux_2026/capture_support.dart';

void main() {
  setUpAll(loadUiuxVisualCaptureFonts);
  testWidgets(
    'Android search scope has a real 48dp edge-to-edge touch target',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final state = AppState(ApiClient());
      addTearDown(state.dispose);
      state.selectedChannel = const GuildChannel(
        id: 'channel-1',
        name: 'Test channel',
        kind: ChannelKind.text,
        admissionClosed: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme().copyWith(platform: TargetPlatform.android),
          home: Scaffold(body: WorkspaceWorkspaceSearchPanel(state: state)),
        ),
      );
      await tester.pumpAndSettle();
      final scope = find.byKey(const ValueKey('workspace-search-scope'));
      final rect = tester.getRect(scope);
      expect(rect.height, greaterThanOrEqualTo(48));
      await captureUiuxBoundary(
        tester,
        find.byType(RepaintBoundary).first,
        fileName: 'search-scope-48dp.png',
        pixelRatio: 1,
      );
      for (final y in [rect.top + 1, rect.center.dy, rect.bottom - 1]) {
        await tester.tapAt(Offset(rect.center.dx, y));
        await tester.pumpAndSettle();
        expect(find.text('Везде').hitTestable(), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Везде').hitTestable(), findsNothing);
        expect(
          tester.widget<DropdownButtonFormField<String>>(scope).initialValue,
          'current',
        );
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byKey(const ValueKey('workspace-search-query')),
                  matching: find.byType(TextField),
                ),
              )
              .controller!
              .text,
          isEmpty,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
