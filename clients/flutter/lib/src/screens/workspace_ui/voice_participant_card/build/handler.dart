import 'participant_details/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceParticipantCardBuildBinding
    on WorkspaceVoiceParticipantCardContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceVoiceParticipantCardBuild(context);
  }
}

extension WorkspaceVoiceParticipantCardBuildAction
    on WorkspaceVoiceParticipantCardContext {
  Widget executeWorkspaceVoiceParticipantCardBuild(BuildContext context) {
    final presentation = VoiceParticipantPresentation.resolve(
      muted: muted,
      microphoneUnavailable: microphoneUnavailable,
      deafened: deafened,
      speaking: speaking,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: presentation.isSpeaking
              ? GcColors.success
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          renderVoiceParticipantCardParticipantDetails(presentation),
          if (hasScreen)
            Positioned(
              top: 0,
              left: 0,
              child: Semantics(
                label: 'Участник показывает экран',
                image: true,
                child: ExcludeSemantics(
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: GcColors.raised,
                      border: Border.all(color: GcColors.border),
                      borderRadius: BorderRadius.circular(GcRadii.sm),
                    ),
                    child: const Icon(
                      Icons.desktop_windows_outlined,
                      size: 16,
                      color: GcColors.accentText,
                    ),
                  ),
                ),
              ),
            ),
          if (volume != null && onVolumeChanged != null)
            Positioned(
              top: -16,
              right: 0,
              child: ParticipantVolumeMenu(
                warning: state.voiceVolumeWarning,
                name: name,
                volume: volume!,
                onChanged: onVolumeChanged!,
                onChangeEnd: () => unawaited(state.flushVoiceVolumes()),
              ),
            ),
        ],
      ),
    );
  }
}
