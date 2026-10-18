import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/setup/open_dialog/dialog.dart';

// The shipping desktop chrome has its own Close tooltip. A native dialog
// journey must not select or count controls outside the active modal.
Finder screenSetupControl(Finder control) =>
    find.descendant(of: find.byType(ScreenShareSetupDialog), matching: control);
