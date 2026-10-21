import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class MemberPopoverLayout extends SingleChildLayoutDelegate {
  const MemberPopoverLayout({required this.anchor, required this.bounds});
  final Rect anchor, bounds;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(0, math.min(288, bounds.width)),
        maxHeight: math.max(0, bounds.height),
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final right = anchor.right + 8, left = anchor.left - childSize.width - 8;
    final x = right + childSize.width <= bounds.right
        ? right
        : left >= bounds.left
        ? left
        : anchor.right - childSize.width;
    return Offset(
      x.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - childSize.width),
      ),
      anchor.top.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(MemberPopoverLayout oldDelegate) =>
      anchor != oldDelegate.anchor || bounds != oldDelegate.bounds;
}
