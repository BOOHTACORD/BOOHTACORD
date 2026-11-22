import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/role_permissions/panel.dart';
import 'package:boohtacord_desktop/src/features/admin/role_permissions/lifecycle/state.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';

import 'api_fixture.dart';

class _SaveApi extends AccessibleAdminApi {
  int saves = 0;
  @override
  Future<void> saveMemberRolePolicy({
    required int revision,
    required Map<GuildPermission, bool> values,
    required bool confirmDeleteGrants,
  }) async => saves++;
}

void main() {
  for (final change in ['owner removed', 'values reloaded', 'draft changed']) {
    testWidgets('delete confirmation cancels save after $change', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      final api = _SaveApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, show, child) => show
                  ? RolePermissionsPanel(api: api, onSaved: () async {})
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<RolePermissionsState>(
        find.byType(RolePermissionsPanel),
      );
      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'Удалять текстовые каналы'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      switch (change) {
        case 'owner removed':
          visible.value = false;
        case 'values reloaded':
          await state.loadRoles(reset: true);
        case 'draft changed':
          state.mutate(() => state.draft[GuildPermission.voiceDelete] = true);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Выдать'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.saves, 0);
    });
  }
}
