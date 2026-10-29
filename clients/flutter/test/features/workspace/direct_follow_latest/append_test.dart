import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';
import 'capture.dart';

void main() {
  testWidgets('incoming DM at latest is visible without user scroll', (
    tester,
  ) async {
    final h = Harness(tester);
    addTearDown(h.close);
    await h.mount();
    await h.latest();
    await h.append();
    await captureTail(tester);
    expect(h.scroll.position.extentAfter, lessThanOrEqualTo(1));
    final incoming = find.text('Incoming fixture 40');
    expect(incoming, findsOneWidget);
    final viewport = tester.getRect(h.list), body = tester.getRect(incoming);
    expect(body.top, greaterThanOrEqualTo(viewport.top));
    expect(body.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  testWidgets('incoming DM preserves a manual older position and draft', (
    tester,
  ) async {
    final h = Harness(tester);
    addTearDown(h.close);
    await h.mount();
    await h.latest();
    await tester.drag(h.list, const Offset(0, 420));
    await tester.pumpAndSettle();
    expect(h.scroll.position.extentAfter, greaterThan(200));
    final offset = h.scroll.offset;
    final composer = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Написать сообщение…',
    );
    await tester.enterText(composer, 'Unsent own draft');
    await h.append();
    expect(h.scroll.offset, closeTo(offset, 1));
    expect(
      tester.widget<TextField>(composer).controller!.text,
      'Unsent own draft',
    );
  });
}
