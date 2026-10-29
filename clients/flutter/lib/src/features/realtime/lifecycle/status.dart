import 'package:flutter/material.dart';

import '../../workspace/short_viewport/policy.dart';

import 'controller.dart';

class RealtimeRecoveryStatus extends StatelessWidget {
  const RealtimeRecoveryStatus({super.key, required this.controller});
  final RealtimeController controller;
  static bool isVisible(RealtimeController controller) =>
      !controller.connected && controller.attempt != 0;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, _) {
      if (!isVisible(controller)) {
        return const SizedBox.shrink();
      }
      if (shortNativeEditingViewport(context)) {
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      controller.attempt >= 5
                          ? 'Сервер пока недоступен'
                          : 'Восстанавливаем подключение…',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Повторить подключение',
                onPressed: controller.connecting || controller.socket != null
                    ? null
                    : controller.retryNow,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
      }
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  controller.attempt >= 5
                      ? 'Сервер пока недоступен'
                      : 'Восстанавливаем подключение…',
                ),
              ),
              TextButton(
                onPressed: controller.connecting || controller.socket != null
                    ? null
                    : controller.retryNow,
                child: const Text('Повторить подключение'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
