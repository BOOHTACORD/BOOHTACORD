import 'package:flutter/material.dart';

import '../remote_lifecycle/controller.dart';

class RemoteNotificationNotice extends StatelessWidget {
  const RemoteNotificationNotice({super.key, required this.controller});
  final RemoteNotificationController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final text = controller.hint.isNotEmpty
          ? controller.hint
          : controller.error;
      if (text == null || text.isEmpty) return const SizedBox.shrink();
      return Semantics(
        liveRegion: true,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(text)),
                IconButton(
                  tooltip: 'Скрыть уведомление',
                  onPressed: () {
                    controller.hint = '';
                    controller.error = null;
                    controller.changed();
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
