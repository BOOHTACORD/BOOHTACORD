import 'participants_grid/handler.dart';
import '../../error_banner/component.dart';
import '../../people_word/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceParticipantRoomBuildBinding
    on WorkspaceVoiceParticipantRoomContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceVoiceParticipantRoomBuild(context);
  }
}

extension WorkspaceVoiceParticipantRoomBuildAction
    on WorkspaceVoiceParticipantRoomContext {
  Widget executeWorkspaceVoiceParticipantRoomBuild(
    BuildContext context,
  ) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              state.voicePhase == VoicePhase.reconnecting
                  ? 'Восстанавливаем связь · состояние микрофона сохранено'
                  : '${participants.length + 1} ${workspacePeopleWord(participants.length + 1)} в комнате'
                        '${screens.isEmpty ? '' : ' · демонстраций: ${screens.length}'}',
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 18),
            WorkspaceErrorBanner(message: state.error!),
          ],
          if (state.microphoneUnavailable) ...[
            const SizedBox(height: 14),
            VoiceMicrophoneUnavailableNotice(
              useTouchPushToTalk:
                  state.usesTouchPushToTalk &&
                  state.audioActivationMode == AudioActivationMode.ptt,
              onRetry: state.audioActivationMode == AudioActivationMode.ptt
                  ? null
                  : () => unawaited(state.toggleMicrophone()),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, gridConstraints) {
              final minWidth = MediaQuery.textScalerOf(context)
                  .scale(136)
                  .clamp(160.0, 320.0);
              final columns =
                  ((gridConstraints.maxWidth + 12) / (minWidth + 12)).floor();
              return renderVoiceParticipantRoomParticipantsGrid(
                columns < 1 ? 1 : columns,
              );
            },
          ),
        ],
      ),
    ),
  );
}
