import 'package:flutter/material.dart';

/// Mobile content placement when a selected screen is pinned.
class WorkspacePinnedScreenMobileContent extends StatelessWidget {
  const WorkspacePinnedScreenMobileContent({
    super.key,
    required this.content,
    required this.mini,
  });
  final Widget content;
  final Widget mini;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        Expanded(child: content),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (constraints.maxHeight - 220).clamp(
                  constraints.maxHeight < 96 ? constraints.maxHeight : 96.0,
                  constraints.maxHeight,
                ),
              ),
              child: mini,
            ),
          ),
        ),
      ],
    ),
  );
}
