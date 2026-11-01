import '../../../native_bindings.dart';
import '../../../search_avatar_foreground/component.dart';
import '../../../voice_avatar_color/component.dart';
import '../../lifecycle/context.dart';

extension VoiceParticipantCardParticipantDetailsRenderer
    on WorkspaceVoiceParticipantCardContext {
  Widget renderVoiceParticipantCardDetails(
    BuildContext context,
    VoiceParticipantPresentation presentation,
  ) {
    final textScale = MediaQuery.textScalerOf(context)
        .scale(1)
        .clamp(1.0, 2.0)
        .toDouble();
    final displayName = name;
    final avatarSeed = avatarIdentity ?? previewIdentity;
    final statusIcon = deafened
        ? Icons.headset_off
        : muted || microphoneUnavailable
        ? Icons.mic_off
        : presentation.isSpeaking
        ? Icons.graphic_eq
        : Icons.mic;
    final statusColor = deafened || muted
        ? GcColors.danger
        : microphoneUnavailable
        ? GcColors.warning
        : presentation.isSpeaking
        ? GcColors.success
        : GcColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AuthenticatedAvatar(
            state: state,
            name: name,
            avatarUrl: avatarUrl,
            radius: 20,
            backgroundColor: workspaceVoiceAvatarColor(avatarSeed),
            fallbackText: name.trim().isEmpty
                ? '?'
                : name.trim().characters.take(2).toString().toUpperCase(),
            fallbackColor: workspaceSearchAvatarForeground(avatarSeed),
            fallbackFontSize: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 60 * textScale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: name,
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Semantics(
                        label: presentation.label,
                        child: Tooltip(
                          message: presentation.label,
                          child: Icon(statusIcon, size: 16, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  if (watchingScreen)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Смотрит трансляцию',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: GcColors.textSecondary,
                          fontSize: 11 * textScale,
                          height: 1.15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (volume != null && onVolumeChanged != null) ...[
            const SizedBox(width: 8),
            ParticipantVolumeMenu(
              warning: state.voiceVolumeWarning,
              name: name,
              volume: volume!,
              onChanged: onVolumeChanged!,
              onChangeEnd: () => unawaited(state.flushVoiceVolumes()),
            ),
          ],
        ],
      ),
    );
  }
}
