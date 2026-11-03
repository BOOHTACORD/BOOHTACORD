import '../../../status_dot/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceDockDisconnectNoticeRenderer on WorkspaceVoiceDockContext {
  Padding renderVoiceDockDisconnectNotice() => Padding(
    padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 0),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: '$workspaceStatus · ${state.voiceChannel!.name}',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  if (workspaceConnected)
                    const Icon(
                      Icons.headphones_outlined,
                      size: 16,
                      color: GcColors.success,
                    )
                  else
                    WorkspaceStatusDot(
                      color: state.voicePhase == VoicePhase.reconnecting
                          ? GcColors.warning
                          : GcColors.success,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workspaceStatus,
                          style: TextStyle(
                            color: state.voicePhase == VoicePhase.reconnecting
                                ? GcColors.warning
                                : GcColors.success,
                            fontSize: 12,
                            fontWeight: workspaceConnected
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          workspaceSubtitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: GcColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (workspaceConnected)
          if (compact ||
              state.voicePingMs != null ||
              state.voiceConnectionQuality != ConnectionQuality.unknown)
            VoiceQualityIndicator(
              quality: state.voiceConnectionQuality,
              pingMs: state.voicePingMs,
              compact: compact,
              showPing: false,
            )
          else
            Semantics(
              container: true,
              label:
                  'Качество соединения: ${voiceConnectionQualityLabel(state.voiceConnectionQuality)} · ping —',
              child: const SizedBox.shrink(),
            ),
      ],
    ),
  );
}
