import 'package:flutter/material.dart';

import 'controller.dart';

class RealtimeRecoveryStatus extends StatelessWidget {
  const RealtimeRecoveryStatus({super.key, required this.controller});
  final RealtimeController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_, _) {
      if (controller.connected || controller.attempt == 0)
        return const SizedBox.shrink();
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
