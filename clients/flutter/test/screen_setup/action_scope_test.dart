import 'package:boohtacord_desktop/src/features/screen/setup/open_dialog/dialog.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/screen_setup_controls.dart';

void main() {
  testWidgets('native action queries exclude the window chrome close button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () {},
                  icon: const Icon(Icons.close),
                ),
                TextButton(
                  child: const Text('Open'),
                  onPressed: () => ScreenShareSetupDialog.show(
                    context,
                    initialQuality: ScreenShareQuality.balanced,
                    allowSourceSelection: false,
                    updating: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Закрыть'), findsNWidgets(2));
    for (final control in [
      find.byTooltip('Закрыть'),
      find.widgetWithText(TextButton, 'Отмена'),
      find.byKey(const ValueKey('start-screen-share')),
    ]) {
      expect(screenSetupControl(control), findsOneWidget);
      expect(screenSetupControl(control).hitTestable(), findsOneWidget);
    }
    await tester.tap(screenSetupControl(find.byTooltip('Закрыть')));
    await tester.pumpAndSettle();
    expect(find.byType(ScreenShareSetupDialog), findsNothing);
    expect(find.byTooltip('Закрыть'), findsOneWidget);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));
}
