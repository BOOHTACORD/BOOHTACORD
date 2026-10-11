import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boohtacord_desktop/src/desktop_window_options.dart';

void main() {
  test('desktop window permits the documented 800 px workspace width', () {
    expect(desktopWindowOptions.minimumSize, const Size(800, 680));
    expect(desktopWindowOptions.size, const Size(1440, 900));
  });
}
