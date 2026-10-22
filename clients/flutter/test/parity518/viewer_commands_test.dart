import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/screens/screen_fullscreen_overlay.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets(
      'exit preserves stream; stop is a separate reachable command $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var exits = 0, stops = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: ScreenFullscreenOverlay(
                publisherName: 'Очень длинное имя участника демонстрации',
                video: const ColoredBox(color: Colors.black),
                onClose: () => exits++,
                onStopWatching: () => stops++,
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Выйти из полноэкранного режима'));
        expect(exits, 1);
        expect(stops, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            home: ScreenFullscreenOverlay(
              publisherName: 'Участник',
              video: const SizedBox(),
              onClose: () => exits++,
              onStopWatching: () => stops++,
            ),
          ),
        );
        await tester.tap(find.byTooltip('Остановить просмотр'));
        expect(stops, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
