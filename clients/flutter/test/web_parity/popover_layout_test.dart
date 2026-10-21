import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/members_panel/popover_layout.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
    for (final keyboard in [0.0, 220.0]) {
      testWidgets('profile stays inside $width x 480 with IME $keyboard', (
        t,
      ) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 480);
        addTearDown(t.view.reset);
        final bounds = Rect.fromLTRB(8, 24, width - 8, 472 - keyboard);
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomSingleChildLayout(
                delegate: MemberPopoverLayout(
                  anchor: Rect.fromLTWH(width - 48, 430, 40, 40),
                  bounds: bounds,
                ),
                child: SingleChildScrollView(
                  key: const ValueKey('profile-bounds'),
                  child: SizedBox(
                    width: 288,
                    height: 900,
                    child: Text(List.filled(80, 'Имя участника').join('\n')),
                  ),
                ),
              ),
            ),
          ),
        );
        final rect = t.getRect(find.byKey(const ValueKey('profile-bounds')));
        expect(rect.left, greaterThanOrEqualTo(bounds.left));
        expect(rect.right, lessThanOrEqualTo(bounds.right));
        expect(rect.top, greaterThanOrEqualTo(bounds.top));
        expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
        expect(t.takeException(), isNull);
        await t.drag(find.byType(SingleChildScrollView), const Offset(0, -150));
        await t.pump();
        expect(
          Scrollable.of(t.element(find.byType(Text))).position.pixels,
          greaterThan(0),
        );
      });
    }
  }
}
