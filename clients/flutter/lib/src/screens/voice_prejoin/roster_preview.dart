import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../../features/voice/roster_state/controller.dart';
import 'member_row.dart';

class VoiceRosterPreview extends StatelessWidget {
  const VoiceRosterPreview({
    super.key,
    required this.state,
    required this.channelId,
    this.compact = false,
  });
  final AppState state;
  final String channelId;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final owner = state.voiceRoster;
    final roster = state.voiceRosters
        ?.where((item) => item.channelId == channelId)
        .firstOrNull;
    final unavailable = state.voiceRosterError != null;
    final stale = owner.phase == VoiceRosterPhase.stale && roster != null;
    final expired = owner.phase == VoiceRosterPhase.sessionExpired;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: roster == null
          ? 'Состав голосового канала'
          : roster.participants.isEmpty
          ? 'Голосовой канал пуст'
          : 'Сейчас в канале: ${roster.participants.length}',
      child: Container(
        width: double.infinity,
        padding: compact ? EdgeInsets.zero : const EdgeInsets.all(12),
        decoration: compact
            ? null
            : BoxDecoration(
                color: GcColors.raised,
                borderRadius: BorderRadius.circular(GcRadii.md),
                border: Border.all(color: GcColors.border),
              ),
        child: Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (!compact)
              Text(
                roster == null || roster.participants.isEmpty
                    ? 'Участники голосового канала'
                    : '${stale ? 'Последний состав' : 'Сейчас в канале'}: ${roster.participants.length}',
                style: const TextStyle(
                  color: GcColors.text,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            if (!compact) const SizedBox(height: 8),
            if (stale || unavailable || expired)
              Semantics(
                liveRegion: true,
                child: Text(
                  expired
                      ? 'Сессия завершена. Войдите снова.'
                      : stale
                      ? 'Состав устарел. Не удалось обновить состав комнаты.'
                      : 'Не удалось обновить состав комнаты.',
                  style: const TextStyle(color: GcColors.warning, fontSize: 12),
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                ),
              ),
            if (roster == null && !unavailable && !expired)
              Semantics(
                liveRegion: true,
                child: const Text(
                  'Проверяем, кто сейчас в комнате…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: GcColors.muted, fontSize: 12),
                ),
              )
            else if (roster?.participants.isEmpty == true)
              Text(
                stale ? 'Последний состав был пустым.' : 'Пока никого нет.',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: const TextStyle(color: GcColors.muted, fontSize: 13),
              )
            else if (roster != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < roster.participants.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(height: 8),
                        VoiceRosterMemberRow(
                          participant: roster.participants[index],
                          state: state,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if ((stale || unavailable) && !expired)
              TextButton.icon(
                key: const ValueKey('retry-voice-roster'),
                onPressed: owner.canRetry ? owner.retryVoiceRosters : null,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Повторить попытку'),
              ),
          ],
        ),
      ),
    );
  }
}
