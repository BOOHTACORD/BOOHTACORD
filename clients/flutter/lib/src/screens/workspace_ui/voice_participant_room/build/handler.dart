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
  ) => ColoredBox(
    color: GcColors.canvas,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 792),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.voicePhase == VoicePhase.reconnecting
                            ? 'Восстанавливаем связь · состояние микрофона сохранено'
                            : state.voicePhase == VoicePhase.listener
                            ? 'Режим слушателя'
                            : 'В голосе',
                        style: const TextStyle(
                          color: GcColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _voiceRoomSummary(
                          participants.length + 1,
                          screens.length +
                              (state.screenSharePhase ==
                                      ScreenSharePhase.sharing
                                  ? 1
                                  : 0),
                        ),
                        style: const TextStyle(
                          color: GcColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                    onRetry:
                        state.audioActivationMode == AudioActivationMode.ptt
                        ? null
                        : () => unawaited(state.toggleMicrophone()),
                  ),
                ],
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, gridConstraints) {
                    final textScale = MediaQuery.textScalerOf(context)
                        .scale(1)
                        .clamp(1.0, 2.0)
                        .toDouble();
                    final minWidth = 280 * textScale;
                    final fittingColumns =
                        ((gridConstraints.maxWidth + 16) / (minWidth + 16))
                            .floor();
                    final columns = fittingColumns
                        .clamp(1, participants.length + 1)
                        .toInt();
                    return renderVoiceParticipantRoomParticipantsGrid(columns);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _voiceRoomSummary(int participantCount, int screenCount) {
  final people = '$participantCount ${workspacePeopleWord(participantCount)}';
  if (screenCount <= 0) return people;
  final screenWord = switch (screenCount % 100) {
    >= 11 && <= 14 => 'демонстраций',
    _ => switch (screenCount % 10) {
      1 => 'демонстрация',
      2 || 3 || 4 => 'демонстрации',
      _ => 'демонстраций',
    },
  };
  return '$people · $screenCount $screenWord экрана';
}
