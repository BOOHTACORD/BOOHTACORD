import 'package:boohtacord_desktop/src/features/workspace/short_viewport/policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'only short native landscape editing uses the compact status row',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final cases = [
        (TargetPlatform.android, const Size(832, 384), 215.0, true),
        (TargetPlatform.iOS, const Size(832, 384), 215.0, true),
        (TargetPlatform.windows, const Size(832, 384), 215.0, false),
        (TargetPlatform.macOS, const Size(832, 384), 215.0, false),
        (TargetPlatform.linux, const Size(832, 384), 215.0, false),
        (TargetPlatform.android, const Size(390, 844), 300.0, false),
        (TargetPlatform.android, const Size(832, 384), 0.0, false),
        (TargetPlatform.android, const Size(1024, 384), 215.0, false),
        (TargetPlatform.android, const Size(832, 440), 200.0, false),
        (TargetPlatform.android, const Size(832, 439), 200.0, true),
      ];
      for (final (platform, size, keyboard, expected) in cases) {
        debugDefaultTargetPlatformOverride = platform;
        tester.view.physicalSize = size;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        bool? actual;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                actual = shortNativeEditingViewport(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();
        expect(actual, expected, reason: '$platform $size IME$keyboard');
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
