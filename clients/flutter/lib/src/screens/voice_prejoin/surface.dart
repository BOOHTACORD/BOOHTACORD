import 'package:flutter/material.dart';

import '../../theme.dart';

class VoicePrejoinSurface extends StatelessWidget {
  const VoicePrejoinSurface({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final width = viewport.width;
    final compact = width <= 600;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        compact ? 32 : (viewport.height * .06).clamp(16, 56).toDouble() + 16,
        16,
        40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            key: const ValueKey('voice-prejoin-card'),
            width: double.infinity,
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 20)
                : const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: GcColors.surface,
              borderRadius: BorderRadius.circular(GcRadii.shell),
              border: Border.all(color: GcColors.border),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}
