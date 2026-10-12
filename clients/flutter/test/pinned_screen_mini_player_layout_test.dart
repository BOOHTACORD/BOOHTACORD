import 'package:flutter/material.dart';
import 'package:boohtacord_desktop/src/widgets/screen_frame_gate.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/pinned_screen_mini_player/component.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/workspace_screen/build/mobile_layers/pinned_content/handler.dart';

void main() {
  testWidgets(
    'waiting preview scrolls within constrained height without overflow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 296,
              height: 60,
              child: ScreenFrameGate(
                generation: 'owned-test',
                waitingMessage: 'Демонстрация завершена',
                builder: (context, onFrame) => const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Демонстрация завершена'), findsOneWidget);
    },
  );
  for (final width in [320.0, 393.0]) {
    testWidgets(
      'pinned production preview reserves composer with keyboard at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 350);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final state = AppState(ApiClient());
        addTearDown(state.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WorkspacePinnedScreenMobileContent(
                content: Column(
                  children: [
                    const SizedBox(height: 56),
                    const Expanded(child: SizedBox()),
                    const SizedBox(
                      height: 120,
                      child: TextField(key: ValueKey('short-composer')),
                    ),
                  ],
                ),
                mini: SizedBox(
                  width: width - 24,
                  child: WorkspacePinnedScreenMiniPlayer(
                    state: state,
                    identity: 'synthetic',
                    selectedIdentity: null,
                    pinnedMiniVisible: true,
                    fullscreenSelection: null,
                    onReturnToVoice: () {},
                    onStopWatching: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final composer = tester.getRect(
              find.byKey(const ValueKey('short-composer')),
            ),
            mini = tester.getRect(find.byType(WorkspacePinnedScreenMiniPlayer));
        expect(composer.overlaps(mini), false);
        expect(composer.height, 120);
        expect(
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.byTooltip('К голосу'),
                      matching: find.byType(IconButton),
                    )
                    .first,
              )
              .height,
          greaterThanOrEqualTo(40),
        );
        expect(
          tester.getRect(find.byTooltip('Остановить просмотр')).bottom,
          lessThanOrEqualTo(mini.bottom),
        );
      },
    );
  }
  for (final width in [320.0, 393.0]) {
    for (final composerHeight in [64.0, 180.0]) {
      testWidgets(
        'pinned screen preserves $composerHeight composer at $width',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 700);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final focus = FocusNode();
          addTearDown(focus.dispose);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: WorkspacePinnedScreenMobileContent(
                  content: Column(
                    children: [
                      const Expanded(child: SizedBox()),
                      SizedBox(
                        height: composerHeight,
                        child: TextField(
                          key: const ValueKey('composer'),
                          focusNode: focus,
                        ),
                      ),
                    ],
                  ),
                  mini: SizedBox(
                    key: const ValueKey('mini'),
                    width: width - 24,
                    height: 260,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('К голосу'),
                    ),
                  ),
                ),
              ),
            ),
          );
          final mini = tester.getRect(find.byKey(const ValueKey('mini'))),
              composer = tester.getRect(find.byKey(const ValueKey('composer')));
          expect(
            mini.overlaps(composer),
            isFalse,
            reason: 'Selected video must not cover the message input, including reply/attachment expansion',
          );
          expect(mini.left, greaterThanOrEqualTo(0));
          expect(mini.right, lessThanOrEqualTo(width));
          await tester.tap(find.byKey(const ValueKey('composer')));
          await tester.pump();
          expect(focus.hasFocus, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
