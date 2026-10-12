import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme.dart';

class SetupSurface extends StatelessWidget {
  const SetupSurface({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final preferredHeight = math.min(760.0, media.size.height * .9);
    final keyboardSafeHeight =
        media.size.height -
        media.viewInsets.vertical -
        media.padding.vertical -
        40;
    final height = math
        .min(preferredHeight, math.max(0.0, keyboardSafeHeight))
        .toDouble();
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 960, maxHeight: height),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GcColors.sidebar,
            border: Border.all(color: GcColors.border),
            borderRadius: BorderRadius.circular(GcRadii.shell),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 42,
                offset: Offset(0, 22),
              ),
            ],
          ),
          child: SizedBox(
            width: 960,
            height: height,
            child: Material(
              color: GcColors.sidebar,
              borderRadius: BorderRadius.circular(GcRadii.shell),
              clipBehavior: Clip.antiAlias,
              child: Column(children: children),
            ),
          ),
        ),
      ),
    );
  }
}
