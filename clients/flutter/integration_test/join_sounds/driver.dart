import 'package:boohtacord_desktop/src/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class QaSoundProfileDriver {
  QaSoundProfileDriver(this.tester);
  final WidgetTester tester;
  Future<void> settled() async {
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Обрабатываем мелодию…').evaluate().isEmpty) return;
    }
    fail('Sound operation did not settle');
  }

  Future<void> tap(String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    for (var i = 0; i < 8 && target.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(
        find
            .descendant(
              of: find.byType(ProfileScreen),
              matching: find.byType(ListView),
            )
            .first,
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
    }
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await settled();
  }
}
