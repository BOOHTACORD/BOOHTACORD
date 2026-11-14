import 'package:flutter/material.dart';

import '../../../../models.dart';
import '../controller.dart';
import '../welcome_selector.dart';

class GuildSettingsPresentation extends StatelessWidget {
  const GuildSettingsPresentation({
    super.key,
    required this.state,
    required this.name,
    required this.channels,
    required this.voiceChannels,
    required this.onSave,
    required this.onLoad,
    required this.onWelcomeChanged,
    required this.onAfkChannelChanged,
    required this.onAfkTimeoutChanged,
    required this.onCancel,
    required this.onNameChanged,
    this.telemetry,
  });
  final Widget? telemetry;
  final GuildSettingsController state;
  final TextEditingController name;
  final List<GuildChannel> channels;
  final List<GuildChannel> voiceChannels;
  final VoidCallback onSave, onLoad, onCancel;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String?> onWelcomeChanged;
  final ValueChanged<String?> onAfkChannelChanged;
  final ValueChanged<int> onAfkTimeoutChanged;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 840;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 0 : 24,
            0,
            compact ? 0 : 24,
            24,
          ),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: compact ? double.infinity : 600,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Гильдия',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    onChanged: onNameChanged,
                    enabled: !state.busy && state.revision > 0,
                    decoration: const InputDecoration(
                      labelText: 'Название гильдии',
                      helperText: 'От 1 до 80 символов, без переводов строк.',
                      helperMaxLines: 10,
                    ),
                  ),
                  const SizedBox(height: 24),
                  WelcomeSelector(
                    value: state.welcome,
                    channels: channels,
                    revision: state.revision,
                    busy: state.busy,
                    onChanged: onWelcomeChanged,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    key: ValueKey('afk:${state.revision}:${state.afkChannel}'),
                    initialValue: state.afkChannel ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'AFK-канал'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Не использовать'),
                      ),
                      if (state.afkChannel != null &&
                          !voiceChannels.any(
                            (channel) => channel.id == state.afkChannel,
                          ))
                        DropdownMenuItem(
                          value: state.afkChannel,
                          enabled: false,
                          child: const Text('Выбранный канал недоступен'),
                        ),
                      for (final channel in voiceChannels)
                        DropdownMenuItem(
                          value: channel.id,
                          child: Text(
                            channel.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: state.busy || state.revision == 0
                        ? null
                        : (value) =>
                              onAfkChannelChanged(value == '' ? null : value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'afk-timeout:${state.revision}:${state.afkTimeout}',
                    ),
                    initialValue: state.afkTimeout,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Перемещать после неактивности',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        enabled: false,
                        child: Text('Сначала выберите AFK-канал'),
                      ),
                      for (final seconds in [
                        60,
                        300,
                        600,
                        900,
                        1800,
                        3600,
                        7200,
                        14400,
                        28800,
                        86400,
                      ])
                        DropdownMenuItem(
                          value: seconds,
                          child: Text(
                            seconds < 3600
                                ? '${seconds ~/ 60} мин.'
                                : '${seconds ~/ 3600} ч.',
                          ),
                        ),
                    ],
                    onChanged:
                        state.busy ||
                            state.revision == 0 ||
                            state.afkChannel == null
                        ? null
                        : (value) {
                            if (value != null) onAfkTimeoutChanged(value);
                          },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Таймер сбрасывают действия в BOOHTACORD и активная речь в голосе. В AFK-канале микрофон будет выключен.',
                    ),
                  ),
                  if (state.error != null)
                    Semantics(liveRegion: true, child: Text(state.error!)),
                  if (state.saved)
                    Semantics(
                      liveRegion: true,
                      child: const Text('Настройки сохранены.'),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: state.busy || state.revision == 0 || !state.dirty
                        ? null
                        : onSave,
                    child: Semantics(
                      liveRegion: state.busy,
                      excludeSemantics: state.busy,
                      label: state.busy
                          ? (state.loading
                                ? 'Загружаем настройки гильдии…'
                                : 'Сохраняем настройки гильдии…')
                          : null,
                      child: Text(
                        state.busy
                            ? (state.loading ? 'Загружаем…' : 'Сохраняем…')
                            : 'Сохранить',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: state.busy || (!state.dirty && !state.conflict)
                        ? null
                        : onCancel,
                    child: const Text('Отмена'),
                  ),
                  if (state.conflict)
                    TextButton(
                      onPressed: state.busy ? null : onLoad,
                      child: const Text('Перечитать настройки'),
                    ),
                  if (state.revision == 0 && !state.busy)
                    TextButton(
                      onPressed: onLoad,
                      child: const Text('Загрузить настройки'),
                    ),
                  if (telemetry != null) telemetry!,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
