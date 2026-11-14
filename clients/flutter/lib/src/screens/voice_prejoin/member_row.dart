import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/authenticated_avatar.dart';
import '../../services/voice_avatar_palette.dart';

class VoiceRosterMemberRow extends StatelessWidget {
  const VoiceRosterMemberRow({
    super.key,
    required this.participant,
    required this.state,
    this.compact = false,
  });

  final VoiceRosterMember participant;
  final AppState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final member = state.members
        .where((item) => item.id == participant.accountId)
        .firstOrNull;
    return SizedBox(
      height: GcLayout.voiceMemberRowHeight,
      child: Row(
        children: [
          AuthenticatedAvatar(
            state: state,
            name: participant.displayName,
            avatarUrl: member?.avatarUrl,
            radius: 12,
            backgroundColor: voiceAvatarColor(participant.accountId),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              participant.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          if (participant.screenSharing)
            Tooltip(
              message: 'Показывает экран',
              child: Container(
                decoration: BoxDecoration(
                  color: GcColors.selected,
                  border: Border.all(color: GcColors.accent),
                  borderRadius: BorderRadius.circular(GcRadii.sm),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.desktop_windows_outlined,
                      size: 16,
                      color: GcColors.accentText,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 4),
                      const Text(
                        'Идёт трансляция',
                        style: TextStyle(
                          color: GcColors.accentText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Tooltip(
            message: participant.deafened
                ? 'Не слышит участников'
                : participant.microphoneMuted
                ? 'Микрофон выключен'
                : 'Микрофон включён',
            child: Icon(
              participant.deafened
                  ? Icons.headset_off
                  : participant.microphoneMuted
                  ? Icons.mic_off_outlined
                  : Icons.mic_none_outlined,
              size: 16,
              color: GcColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
