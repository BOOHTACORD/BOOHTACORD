import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceScreenViewerWorkspaceAudioControlsBinding
    on WorkspaceVoiceScreenViewerContext {
  @override
  Widget get workspaceAudioControls {
    return executeWorkspaceVoiceScreenViewerWorkspaceAudioControls();
  }
}

extension WorkspaceVoiceScreenViewerWorkspaceAudioControlsAction
    on WorkspaceVoiceScreenViewerContext {
  Widget executeWorkspaceVoiceScreenViewerWorkspaceAudioControls() =>
      VoiceScreenAudioControls(
        showingLocalScreen: showingLocalScreen,
        screenAudioAvailable: screenAudioAvailable,
        screenAudioVolume: screenAudioVolume,
        screenAudioMuted: screenAudioMuted,
        onToggleScreenAudio: onToggleScreenAudio,
        onScreenAudioVolumeChanged: onScreenAudioVolumeChanged,
      );
}
