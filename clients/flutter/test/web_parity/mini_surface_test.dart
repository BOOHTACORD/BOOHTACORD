import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/pinned_screen_mini_player/component.dart';
import 'package:boohtacord_desktop/src/widgets/pinned_screen_dock.dart';
import 'package:boohtacord_desktop/src/theme.dart';

import '../uiux_2026/capture_support.dart';

void main() {
  testWidgets(
    'production mini pause and reserved controls survive resize, short window and unpin',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1440, 900);
      addTearDown(t.view.reset);
      await loadUiuxVisualCaptureFonts();
      final state = AppState(ApiClient());
      addTearDown(state.dispose);
      final root = GlobalKey();
      var pinned = true;
      await t.pumpWidget(
        RepaintBoundary(
          key: root,
          child: MaterialApp(
            theme: guildTheme(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => PinnedScreenDock(
                  content: const Column(
                    children: [
                      Expanded(child: Text('История')),
                      TextField(key: ValueKey('mini-composer')),
                    ],
                  ),
                  mini: pinned
                      ? SizedBox(
                          width: 360,
                          child: WorkspacePinnedScreenMiniPlayer(
                            state: state,
                            identity: 'screen',
                            selectedIdentity: null,
                            pinnedMiniVisible: true,
                            fullscreenSelection: null,
                            onReturnToVoice: () {},
                            onStopWatching: () => update(() => pinned = false),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      await t.tap(find.byTooltip('Приостановить видео'));
      await t.pump();
      await t.enterText(
        find.byKey(const ValueKey('mini-composer')),
        'Черновик',
      );
      for (final height in [480.0, 240.0]) {
        for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
          t.view.physicalSize = Size(width, height);
          await t.pumpAndSettle();
          expect(find.byTooltip('Продолжить видео'), findsOneWidget);
          final stop = find.byTooltip('Остановить просмотр');
          expect(stop, findsOneWidget);
          final mini = t.getRect(find.byType(WorkspacePinnedScreenMiniPlayer));
          final composer = t.getRect(
            find.byKey(const ValueKey('mini-composer')),
          );
          expect(mini.overlaps(composer), isFalse);
          expect(mini.right, lessThanOrEqualTo(width));
          expect(mini.bottom, lessThanOrEqualTo(height));
          expect(t.getSize(stop).shortestSide, greaterThanOrEqualTo(44));
          expect(t.takeException(), isNull);
          await captureUiuxBoundary(
            t,
            find.byKey(root),
            fileName:
                'parity-mini-${width.toInt()}x${height.toInt()}-scale2.png',
            pixelRatio: 1,
          );
        }
      }
      await t.tap(find.byTooltip('Остановить просмотр'));
      await t.pumpAndSettle();
      expect(find.byType(WorkspacePinnedScreenMiniPlayer), findsNothing);
      expect(find.text('Черновик'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
