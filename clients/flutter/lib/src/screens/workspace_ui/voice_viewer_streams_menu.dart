import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../voice_screen_selection_rail.dart';

/// Lets viewers switch between active screen shares without reserving a row
/// below the video stage.
class VoiceViewerStreamsMenu extends StatefulWidget {
  const VoiceViewerStreamsMenu({
    super.key,
    required this.choices,
    required this.onSelected,
  });

  final List<VoiceScreenChoice> choices;
  final ValueChanged<String?> onSelected;

  @override
  State<VoiceViewerStreamsMenu> createState() => _VoiceViewerStreamsMenuState();
}

class _VoiceViewerStreamsMenuState extends State<VoiceViewerStreamsMenu> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final maxWidth = math.max(0.0, MediaQuery.sizeOf(context).width - 24);
    final panelWidth = math.min(
      maxWidth,
      math.min(560.0, math.max(216.0, widget.choices.length * 168.0 + 24)),
    );

    return MenuAnchor(
      controller: _controller,
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(GcColors.sidebar),
        elevation: const WidgetStatePropertyAll(12),
        maximumSize: WidgetStatePropertyAll(Size(maxWidth, 280)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            side: const BorderSide(color: GcColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: panelWidth,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Демонстрации в канале · ${widget.choices.length}',
                  style: const TextStyle(
                    color: GcColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                VoiceScreenSelectionRail(
                  choices: widget.choices,
                  onSelected: (identity) {
                    widget.onSelected(identity);
                    _controller.close();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: 'Выбрать демонстрацию',
        child: OutlinedButton.icon(
          onPressed: controller.isOpen ? controller.close : controller.open,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: GcColors.sidebar.withValues(alpha: .94),
            foregroundColor: GcColors.text,
            side: BorderSide(
              color: controller.isOpen ? GcColors.accent : GcColors.border,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.cast_outlined, size: 16),
          label: Text(
            'Трансляции · ${widget.choices.length}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}
