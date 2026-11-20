import '../lifecycle/context.dart';
import '../handler_bindings.dart';
import '../../../../features/voice/background_playback/status.dart';

mixin WorkspaceVoiceDockWorkspaceStatusBinding on WorkspaceVoiceDockContext {
  @override
  String get workspaceStatus {
    return executeWorkspaceVoiceDockWorkspaceStatus();
  }
}

extension WorkspaceVoiceDockWorkspaceStatusAction on WorkspaceVoiceDockContext {
  String executeWorkspaceVoiceDockWorkspaceStatus() =>
      voicePlaybackWorkspaceStatus(
        state.voicePhase,
        backgroundPlaybackUnavailable: state.voicePlaybackBackgroundUnavailable,
      );
}
