import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  testWidgets(
    'admin remount restores previous section within its workspace session',
    (tester) async {
      final state = await mountAdmin(tester);
      final roles = find.byKey(const ValueKey('admin-section-tab-roles'));
      await tester.ensureVisible(roles);
      await tester.tap(roles);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(roles).properties.selected, true);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          home: Scaffold(body: AdminScreen(state: state)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(roles).properties.selected, true);
    },
  );

  testWidgets('clearing the workspace discards the old account admin section', (
    tester,
  ) async {
    final state = await mountAdmin(tester);
    final roles = find.byKey(const ValueKey('admin-section-tab-roles'));
    await tester.ensureVisible(roles);
    await tester.tap(roles);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    state.workspace.clear();
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('admin-section-tab-members')),
          )
          .properties
          .selected,
      true,
    );
  });
}
