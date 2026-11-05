import 'package:flutter/material.dart';

/// Windows Communications attenuation is controlled by the user, not the app.
class WindowsAudioGuidance extends StatelessWidget {
  const WindowsAudioGuidance({super.key});

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    title: const Text('Музыка становится тише при входе в голосовой канал?'),
    children: const [
      Text(
        'Если Windows уменьшает громкость музыки и других приложений, '
        'откройте Панель управления → Звук → Связь → '
        '«Действие не требуется». '
        'Это системная настройка, BOOHTACORD не изменяет её автоматически.',
      ),
    ],
  );
}
