import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture.dart';
import 'fixture.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final input in ['pointer', 'keyboard', 'space']) {
      testWidgets(
        'older DM keeps anchor then reaches incoming via $input at $scale',
        (tester) async {
          final h = Harness(tester);
          addTearDown(h.close);
          await h.mount(textScale: scale);
          await h.latest();
          await tester.drag(h.list, const Offset(0, 420));
          await tester.pumpAndSettle();
          final before = h.scroll.offset;
          final viewportBefore = tester.getRect(h.list);
          final anchor = find
              .descendant(
                of: h.list,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is SelectableText &&
                      ((w.data ?? w.textSpan?.toPlainText())?.startsWith(
                            'Incoming fixture ',
                          ) ??
                          false),
                ),
              )
              .evaluate()
              .map((e) {
                final text = e.widget as SelectableText;
                return (text.data ?? text.textSpan?.toPlainText())!;
              })
              .firstWhere((text) {
                final rect = tester.getRect(find.text(text));
                return rect.top >= viewportBefore.top &&
                    rect.bottom < viewportBefore.bottom;
              });
          final anchorTop = tester.getTopLeft(find.text(anchor)).dy;
          final composer = find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.hintText == 'Написать сообщение…',
          );
          await tester.enterText(composer, 'Unsent own draft');
          final editor = tester.widget<TextField>(composer).controller!;
          editor.selection = const TextSelection(
            baseOffset: 2,
            extentOffset: 8,
          );
          final value = editor.value;
          await h.append();
          expect(h.scroll.offset, closeTo(before, 1));
          expect(
            tester.getTopLeft(find.text(anchor)).dy,
            closeTo(anchorTop, 1),
          );
          if (input == 'pointer') {
            await captureTail(tester, name: 'older-$scale');
          }
          final jump = find.byKey(const ValueKey('dm-jump-latest-action'));
          expect(jump.hitTestable(), findsOneWidget);
          expect(tester.getSize(jump).height, greaterThanOrEqualTo(44));
          if (input == 'pointer') {
            await tester.tap(jump);
          } else {
            bool focused() {
              var found = false;
              FocusManager.instance.primaryFocus?.context
                  ?.visitAncestorElements((element) {
                    found =
                        element.widget.key ==
                        const ValueKey('dm-jump-latest-action');
                    return !found;
                  });
              return found;
            }

            for (var i = 0; i < 12 && !focused(); i++) {
              await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
              await tester.pumpAndSettle();
            }
            expect(focused(), isTrue);
            await tester.sendKeyEvent(
              input == 'space'
                  ? LogicalKeyboardKey.space
                  : LogicalKeyboardKey.enter,
            );
          }
          await tester.pumpAndSettle();
          expect(h.scroll.position.extentAfter, lessThanOrEqualTo(1));
          final body = tester.getRect(find.text('Incoming fixture 40'));
          final viewport = tester.getRect(h.list);
          expect(body.top, greaterThanOrEqualTo(viewport.top));
          expect(body.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(editor.value, value);
          expect(jump, findsNothing);
          if (input == 'pointer') {
            await captureTail(tester, name: 'jumped-$scale');
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
