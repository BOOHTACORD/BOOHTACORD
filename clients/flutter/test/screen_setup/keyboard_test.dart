import 'package:boohtacord_desktop/src/features/screen/setup/open_dialog/dialog.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'source_support.dart';

void main() {
  for (final updating in [false, true]) {
    for (final traverse in [false, true]) {
      testWidgets(
        'Escape cancels updating=$updating after traversal=$traverse',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final capturer = FakeDesktopCapturer();
          final launcher = FocusNode();
          addTearDown(launcher.dispose);
          addTearDown(capturer.close);
          ScreenShareSetupSelection? result;
          var completed = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    focusNode: launcher,
                    onPressed: () async {
                      result = await ScreenShareSetupDialog.show(
                        context,
                        initialQuality: ScreenShareQuality.balanced,
                        allowSourceSelection: !updating,
                        updating: updating,
                        capturer: capturer,
                      );
                      completed = true;
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          launcher.requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(ScreenShareSetupDialog), findsOneWidget);
          if (traverse) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(ScreenShareSetupDialog), findsNothing);
          expect(completed, isTrue);
          expect(result, isNull);
          expect(launcher.hasFocus, isTrue);
          for (final stream in [
            capturer.onAdded,
            capturer.onRemoved,
            capturer.onThumbnailChanged,
            capturer.onNameChanged,
          ]) {
            expect(stream.hasListener, isFalse);
          }
          // A pending enumeration may complete after cancellation without
          // resurrecting a dialog, notifying a disposed inventory or publishing.
          for (final call in capturer.calls) {
            call.complete([]);
          }
          await tester.pump(const Duration(seconds: 5));
          expect(tester.takeException(), isNull);
          expect(capturer.calls.length, updating ? 0 : 1);
        },
        variant: TargetPlatformVariant({TargetPlatform.windows}),
      );
    }
  }
  for (final close in [false, true]) {
    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      testWidgets('keyboard $key activates ${close ? 'X' : 'Cancel'}', (
        tester,
      ) async {
        var completed = false;
        ScreenShareSetupSelection? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await ScreenShareSetupDialog.show(
                      context,
                      initialQuality: ScreenShareQuality.balanced,
                      allowSourceSelection: false,
                      updating: true,
                    );
                    completed = true;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final control = close ? find.byIcon(Icons.close) : find.text('Отмена');
        Focus.of(tester.element(control)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(completed, isTrue);
        expect(result, isNull);
        expect(find.byType(ScreenShareSetupDialog), findsNothing);
      }, variant: TargetPlatformVariant({TargetPlatform.windows}));
    }
  }
}
