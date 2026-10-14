import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/updates/restore/window_bounds.dart';

void main() {
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
