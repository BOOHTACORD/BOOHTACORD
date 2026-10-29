import '../../../native_bindings.dart';
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

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AuthenticatedAvatar(
            state: state,
            name: name,
            avatarUrl: avatarUrl,
            radius: 20,
            fallbackFontSize: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 70 * textScale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 19 * textScale,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: name,
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 3 * textScale),
                  SizedBox(
                    height: 32 * textScale,
                    child: Row(
                      children: [
                        Icon(
                          deafened
                              ? Icons.headset_off
                              : muted || microphoneUnavailable
                              ? Icons.mic_off
                              : presentation.isSpeaking
                              ? Icons.graphic_eq
                              : Icons.mic,
                          size: 12 * textScale,
                          color: deafened
                              ? GcColors.danger
                              : microphoneUnavailable
                              ? GcColors.warning
                              : muted
                              ? GcColors.danger
                              : presentation.isSpeaking
                              ? GcColors.success
                              : GcColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            presentation.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: presentation.isSpeaking
                                  ? GcColors.success
                                  : GcColors.muted,
                              fontSize: 12,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2 * textScale),
                  SizedBox(
                    height: 14 * textScale,
                    child: watchingScreen
                        ? Text(
                            'Смотрит трансляцию',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: GcColors.muted,
                              fontSize: 11,
                              height: 1.15,
                            ),
                          )
                        : null,
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
