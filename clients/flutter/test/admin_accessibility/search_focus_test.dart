import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';
import '../uiux_2026/capture_support.dart';

void main() {
  setUpAll(loadUiuxVisualCaptureFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final keyboardInset in [0.0, 300.0]) {
      testWidgets('member editing retains focus/IME at $scale/$keyboardInset', (
        tester,
      ) async {
        await mountAdmin(
          tester,
          scale: scale,
          platform: TargetPlatform.android,
          insets: EdgeInsets.only(bottom: keyboardInset),
        );
        final field = find.byKey(const ValueKey('admin-member-search'));
        if (scale > 1.5 || keyboardInset > 0) {
          await revealAdminControl(tester, field);
        } else {
          await tester.ensureVisible(field);
        }
        await tester.showKeyboard(field);
        final controller = tester.widget<TextField>(field).controller!;
        final editor = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        final focus = tester.widget<EditableText>(editor).focusNode;
        for (final prefix in ['т', 'те', 'тес', 'тест']) {
          tester.testTextInput.updateEditingValue(
            TextEditingValue(
              text: prefix,
              selection: TextSelection.collapsed(offset: prefix.length),
            ),
          );
          await tester.pump();
          expect(tester.widget<EditableText>(editor).focusNode, same(focus));
          expect(focus.hasFocus, isTrue, reason: prefix);
          expect(tester.testTextInput.hasAnyClients, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);
          expect(tester.widget<TextField>(field).controller!.text, prefix);
        }
        await captureUiuxBoundary(
          tester,
          find.byType(RepaintBoundary).first,
          fileName: 'admin-search-$scale-$keyboardInset.png',
          pixelRatio: 1,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.widget<TextField>(field).controller!.text, 'тест');
        final reset = find.text('Сбросить фильтры');
        if (scale > 1.5 || keyboardInset > 0) {
          await revealAdminControl(tester, reset);
        } else {
          await tester.ensureVisible(reset);
        }
        await tester.pumpAndSettle();
        await tester.tap(reset);
        await tester.pumpAndSettle();
        expect(controller.text, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
