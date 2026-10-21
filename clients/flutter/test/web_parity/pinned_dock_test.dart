import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/widgets/pinned_screen_dock.dart';

void main() {
  testWidgets(
    'reserved mini never overlaps content and resize keeps composer state',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Widget app(bool mini) => MaterialApp(
        home: Scaffold(
          body: PinnedScreenDock(
            content: const Column(
              children: [
                Expanded(child: Text('history')),
                TextField(key: ValueKey('composer')),
              ],
            ),
            mini: mini
                ? const SizedBox(key: ValueKey('mini'), width: 320, height: 240)
                : null,
          ),
        ),
      );
      t.view.physicalSize = const Size(1000, 900);
      await t.pumpWidget(app(true));
      await t.enterText(find.byKey(const ValueKey('composer')), 'Черновик');
      expect(
        t
            .getRect(find.byKey(const ValueKey('composer')))
            .overlaps(t.getRect(find.byKey(const ValueKey('mini')))),
        false,
      );
      t.view.physicalSize = const Size(390, 600);
      await t.pumpAndSettle();
      expect(find.text('Черновик'), findsOneWidget);
      expect(
        t
            .getRect(find.byKey(const ValueKey('composer')))
            .overlaps(t.getRect(find.byKey(const ValueKey('mini')))),
        false,
      );
      await t.pumpWidget(app(false));
      expect(find.text('Черновик'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
