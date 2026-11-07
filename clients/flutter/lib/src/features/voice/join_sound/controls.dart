import 'package:flutter/material.dart';

class JoinSoundControls extends StatelessWidget {
  const JoinSoundControls({
    super.key,
    required this.sound,
    required this.busy,
    required this.error,
    required this.audible,
    required this.upload,
    required this.preview,
    required this.enable,
    required this.remove,
  });
  final Map<String, dynamic>? sound;
  final bool busy, audible;
  final String? error;
  final VoidCallback upload, preview, remove;
  final ValueChanged<bool> enable;
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Персональная мелодия входа'),
        const Text(
          'MP3, WAV или OGG · 0,3–3 секунды · до 2 МиБ. После загрузки включите мелодию отдельно.',
        ),
        OutlinedButton(
          onPressed: busy ? null : upload,
          child: const Text('Загрузить мелодию'),
        ),
        if (sound != null) ...[
          SwitchListTile(
            title: const Text('Использовать при входе в канал'),
            value: sound!['enabled'] == true,
            onChanged: busy ? null : enable,
          ),
          OutlinedButton(
            onPressed: busy || !audible ? null : preview,
            child: const Text('Прослушать мелодию'),
          ),
          TextButton(
            onPressed: busy ? null : remove,
            child: const Text('Удалить мелодию'),
          ),
        ],
        if (busy) const Text('Обрабатываем мелодию…'),
        if (error != null) Semantics(liveRegion: true, child: Text(error!)),
      ],
    ),
  );
}
