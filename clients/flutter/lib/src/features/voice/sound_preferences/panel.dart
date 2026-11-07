import 'package:flutter/material.dart';

import '../sound_playback/runtime.dart';
import 'legacy_panel.dart';

class VoiceSoundSettingsPanel extends StatelessWidget {
  const VoiceSoundSettingsPanel({super.key, required this.runtime});
  final VoiceSoundRuntime runtime;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: runtime,
    builder: (context, _) {
      final prefs = runtime.preferences;
      if (prefs == null) return const Text('Настройки звука недоступны.');
      final ready = prefs.ready;
      final settings = prefs.settings;
      const labels = {
        'enabled': 'Звуковые уведомления',
        'joined': 'Кто-то вошёл',
        'left': 'Кто-то вышел',
        'started': 'Трансляция началась',
        'stopped': 'Трансляция закончилась',
        'allow_custom': 'Мелодии входа других участников',
      };
      return Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LegacySoundReviewPanel(runtime: runtime),
            const Text('Звуки голосового канала'),
            for (final entry in labels.entries)
              SwitchListTile(
                title: Text(entry.value),
                value: settings[entry.key] == true,
                onChanged: ready
                    ? (value) => prefs.update({entry.key: value})
                    : null,
                secondary:
                    ['joined', 'left', 'started', 'stopped'].contains(entry.key)
                    ? IconButton(
                        tooltip: 'Прослушать: ${entry.value}',
                        icon: const Icon(Icons.play_arrow),
                        onPressed: runtime.allows(entry.key)
                            ? () => runtime.submit(entry.key)
                            : null,
                      )
                    : null,
              ),
            Text('Громкость уведомлений: ${settings['volume']}%'),
            Slider(
              value: (settings['volume'] as int).toDouble(),
              max: 100,
              divisions: 100,
              onChanged: ready
                  ? (value) => prefs.update({'volume': value.round()})
                  : null,
            ),
            if (prefs.unsynchronised)
              const Text('Не синхронизировано. Проверьте соединение.'),
          ],
        ),
      );
    },
  );
}
