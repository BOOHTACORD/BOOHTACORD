import 'participant_details/handler.dart';
import 'preview/handler.dart';
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: presentation.isSpeaking ? GcColors.success : GcColors.border,
          width: presentation.isSpeaking ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          renderVoiceParticipantCardPreview(),
          renderVoiceParticipantCardDetails(context, presentation),
        ],
      ),
    );
  }
}
