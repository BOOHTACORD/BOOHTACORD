import 'package:flutter/material.dart';

import '../../features/notifications/settings/mode_items.dart';
import '../../features/notifications/settings/rule_changes.dart';

import '../../app_state.dart';
import 'conversation_choices.dart';

class ConversationNotificationRules extends StatefulWidget {
  const ConversationNotificationRules({super.key, required this.state});
  final AppState state;
  @override
  State<ConversationNotificationRules> createState() => _RulesState();
}

class _RulesState extends State<ConversationNotificationRules> {
  String? selected;
  @override
  Widget build(BuildContext context) {
    final prefs = widget.state.remoteNotifications.preferences,
        settings = prefs?.settings;
    if (prefs == null || settings == null) return const SizedBox.shrink();
    final choices = notificationConversationChoices(widget.state);
    final keys = choices.map((c) => '${c['kind']}:${c['id']}').toList();
    if (!keys.contains(selected)) selected = keys.firstOrNull;
    final index = keys.indexOf(selected ?? '');
    if (index < 0) {
      return const Text(
        'Настройки бесед появятся после создания канала или личной переписки.',
      );
    }
    final choice = choices[index];
    final overrides = (settings['overrides'] as List).whereType<Map>();
    final value =
        overrides
            .where(
              (o) => o['kind'] == choice['kind'] && o['id'] == choice['id'],
            )
            .firstOrNull ??
        settings[choice['kind'] == 'CHANNEL' ? 'text' : 'dm'] as Map;
    Future<void> save(String mode, String? pause) => prefs.update(
      (s) => setConversationNotificationRule(
        s,
        choice['kind']!,
        choice['id']!,
        mode,
        pause,
      ),
    );
    return ExpansionTile(
      title: const Text('Настройки отдельных бесед'),
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          isDense: false,
          itemHeight: null,
          initialValue: selected,
          items: [
            for (var i = 0; i < keys.length; i++)
              DropdownMenuItem(
                value: keys[i],
                child: Text(
                  choices[i]['label']!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: prefs.busy ? null : (v) => setState(() => selected = v),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          isDense: false,
          itemHeight: null,
          key: ValueKey('$selected:${value['mode']}'),
          initialValue: value['mode'] as String,
          items: notificationModeItems,
          onChanged: prefs.busy
              ? null
              : (mode) {
                  if (mode != null) {
                    save(mode, value['paused_until'] as String?);
                  }
                },
        ),
        OutlinedButton(
          onPressed: prefs.busy
              ? null
              : () => save(
                  value['mode'] as String,
                  DateTime.now()
                      .toUtc()
                      .add(const Duration(hours: 1))
                      .toIso8601String(),
                ),
          child: const Text('Пауза на 1 час'),
        ),
        OutlinedButton(
          onPressed: prefs.busy
              ? null
              : () => prefs.update(
                  (s) => resetConversationNotificationRule(
                    s,
                    choice['kind']!,
                    choice['id']!,
                  ),
                ),
          child: const Text('Для этой беседы: использовать общие настройки'),
        ),
      ],
    );
  }
}
