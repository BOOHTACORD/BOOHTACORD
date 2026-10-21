import 'package:flutter/material.dart';

/// Reserves space inside the conversation pane, never above its chrome.
class PinnedScreenDock extends StatefulWidget {
  const PinnedScreenDock({super.key, required this.content, this.mini});
  final Widget content;
  final Widget? mini;
  @override
  State<PinnedScreenDock> createState() => _PinnedScreenDockState();
}

class _PinnedScreenDockState extends State<PinnedScreenDock> {
  final contentKey = GlobalKey(), miniKey = GlobalKey();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final content = KeyedSubtree(key: contentKey, child: widget.content);
      final mini = widget.mini == null
          ? null
          : KeyedSubtree(key: miniKey, child: widget.mini!);
      if (constraints.maxWidth >= 740 && constraints.maxHeight >= 600) {
        return Row(
          children: [
            Expanded(child: content),
            if (mini != null) ...[
              const VerticalDivider(width: 1),
              SizedBox(
                width: 320,
                child: Align(alignment: Alignment.bottomRight, child: mini),
              ),
            ],
          ],
        );
      }
      if (mini != null && constraints.maxHeight < 360) {
        // IME + voice controls can leave less room than header + composer.
        // A bounded conversation remains intact; the short pane can scroll to
        // the focused composer and mini controls instead of overflowing either.
        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 360, child: content),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 48),
                    child: mini,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      final height = constraints.maxHeight < 360
          ? 48.0
          : (constraints.maxHeight - 220).clamp(96.0, 280.0);
      return Column(
        children: [
          Expanded(child: content),
          if (mini != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height),
                  child: mini,
                ),
              ),
            ),
        ],
      );
    },
  );
}
