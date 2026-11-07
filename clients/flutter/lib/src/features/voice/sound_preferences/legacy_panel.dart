import 'package:flutter/material.dart';

import '../sound_playback/runtime.dart';

class LegacySoundReviewPanel extends StatelessWidget {
  const LegacySoundReviewPanel({super.key, required this.runtime});
  final VoiceSoundRuntime runtime;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: runtime,
    builder: (context, _) {
      if (!runtime.legacy.blocked) return const SizedBox.shrink();
      return Column(
        children: [
          const Text(
            'На этом устройстве были выключены старые звуки. Выберите настройки для текущего аккаунта.',
          ),
          TextButton(
            onPressed: runtime.preferences?.ready == true
                ? () => runtime.reviewLegacy(true)
                : null,
            child: const Text('Оставить выключенными'),
          ),
          TextButton(
            onPressed: runtime.preferences?.ready == true
                ? () => runtime.reviewLegacy(false)
                : null,
            child: const Text('Использовать настройки аккаунта'),
          ),
        ],
      );
    },
  );
}
