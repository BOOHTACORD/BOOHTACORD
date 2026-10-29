import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../theme.dart';

bool shortNativeEditingViewport(BuildContext context) {
  // Keep a dependency on inherited metrics even when Scaffold removes insets.
  final media = MediaQuery.of(context);
  final view = MediaQueryData.fromView(View.of(context));
  final native =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final available =
      view.size.height -
      view.viewInsets.bottom -
      view.padding.top -
      view.padding.bottom;
  return native &&
      media.orientation == Orientation.landscape &&
      media.size.width < GcLayout.mobileBreakpoint &&
      view.viewInsets.bottom > 0 &&
      available < 240;
}
