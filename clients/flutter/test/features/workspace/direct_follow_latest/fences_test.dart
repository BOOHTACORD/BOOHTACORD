import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  for (final fence in [
    'new-scroll-choice',
    'logout',
    'DM-left',
    'history-replaced',
  ]) {
    testWidgets('queued DM tail correction yields to $fence', (tester) async {
      final h = Harness(tester);
      addTearDown(h.close);
      await h.mount();
      await h.latest();
      final before = h.scroll.offset;
      final expected = fence == 'new-scroll-choice' ? before - 100 : before;
      // This callback runs after the new build but before its queued correction.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        switch (fence) {
          case 'new-scroll-choice':
            h.scroll.jumpTo(expected);
          case 'logout':
            h.state.user = null;
          case 'DM-left':
            h.state.selectedDirectMessage = null;
          case 'history-replaced':
            h.state.directMessageHistory = List.of(
              h.state.directMessageHistory,
            );
        }
      });
      await h.append();
      expect(h.scroll.offset, closeTo(expected, 1));
      expect(h.scroll.position.extentAfter, greaterThan(1));
    });
  }

  testWidgets(
    'older-page prepend keeps the latest ID and does not force tail',
    (tester) async {
      final h = Harness(tester);
      addTearDown(h.close);
      await h.mount();
      await h.latest();
      final before = h.scroll.offset;
      h.state.directMessageHistory = [
        message(-1),
        ...h.state.directMessageHistory,
      ];
      h.state.notifyListeners();
      await tester.pumpAndSettle();
      expect(h.scroll.offset, closeTo(before, 1));
    },
  );

  testWidgets('replacement history without old tail is not an append', (
    tester,
  ) async {
    final h = Harness(tester);
    addTearDown(h.close);
    await h.mount();
    await h.latest();
    final before = h.scroll.offset;
    h.state.directMessageHistory = List.generate(60, (i) => message(i + 100));
    h.state.notifyListeners();
    await tester.pumpAndSettle();
    expect(h.scroll.offset, closeTo(before, 1));
    expect(h.scroll.position.extentAfter, greaterThan(1));
  });
}
