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
    required this.onSave,
    required this.onLoad,
    required this.onWelcomeChanged,
    required this.onCancel,
    required this.onNameChanged,
    this.telemetry,
  });
  final Widget? telemetry;
  final GuildSettingsController state;
  final TextEditingController name;
  final List<GuildChannel> channels;
  final VoidCallback onSave, onLoad, onCancel;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String?> onWelcomeChanged;
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
