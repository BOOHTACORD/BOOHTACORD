import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/screens/admin_ui/lifecycle/context.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';

import 'fixture.dart';

void main() {
  testWidgets('failed reset link copy clears earlier success', (tester) async {
    var fail = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData' && fail) {
          throw PlatformException(code: 'clipboard-unavailable');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await mountAdmin(tester);
    final reset = find.byKey(const ValueKey('reset-account:account-a'));
    await revealAdminControl(tester, reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    final state = tester.state<AdminScreenStateContext>(
      find.byType(AdminScreen),
    );
    await state.adminCopyResetLink();
    await tester.pumpAndSettle();
    expect(state.adminAccountsStatus, 'Ссылка скопирована.');
    fail = true;
    await state.adminCopyResetLink();
    await tester.pumpAndSettle();
    expect(state.adminAccountsStatus, isNull);
    expect(state.adminAccountsError, contains('clipboard-unavailable'));
    fail = false;
    await state.adminCopyResetLink();
    await tester.pumpAndSettle();
    expect(state.adminAccountsError, isNull);
    expect(state.adminAccountsStatus, 'Ссылка скопирована.');
  });
}
