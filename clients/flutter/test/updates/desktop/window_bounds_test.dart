import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/restore/window_bounds.dart';

void main() {
  test(
    'a valid baseline keeps identical bounds on an unchanged small display',
    () {
      final screens = [const Rect.fromLTWH(0, 0, 1024, 740)];
      final baseline = visibleWindowBounds(
        const Rect.fromLTWH(40, 40, 1200, 800),
        screens,
      );
      expect(baseline.intersect(screens.single), baseline);
      expect(visibleWindowBounds(baseline, screens), baseline);
    },
  );

  test('a removed monitor cannot strand the restored window off screen', () {
    final restored = visibleWindowBounds(
      const Rect.fromLTWH(3000, 100, 1400, 1000),
      [const Rect.fromLTWH(0, 0, 1200, 800)],
    );
    expect(restored, const Rect.fromLTWH(0, 0, 1200, 800));
    expect(
      visibleWindowBounds(const Rect.fromLTWH(50, 40, 800, 600), [
        const Rect.fromLTWH(0, 0, 1200, 800),
      ]),
      const Rect.fromLTWH(50, 40, 800, 600),
    );
  });
}
