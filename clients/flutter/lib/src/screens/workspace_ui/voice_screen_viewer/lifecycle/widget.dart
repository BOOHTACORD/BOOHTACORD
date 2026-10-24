import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceVoiceScreenViewer extends WorkspaceVoiceScreenViewerContext
    with
        WorkspaceVoiceScreenViewerBuildBinding,
        WorkspaceVoiceScreenViewerWorkspaceAudioControlsBinding,
        WorkspaceVoiceScreenViewerWorkspaceStreamRailBinding {
  const WorkspaceVoiceScreenViewer({
    super.key,
    required super.state,
    required super.track,
    required super.rendererOwner,
    required super.publisherName,
    required super.screens,
    required super.selectedIdentity,
    required super.viewerGeneration,
    required super.onFirstFrameRendered,
    required super.localScreenAvailable,
    required super.showingLocalScreen,
    required super.receiverTrack,
    required super.sourceTrackName,
    required super.localName,
    required super.localMuted,
    required super.localSpeaking,
    required super.participants,
    required super.screenAudioAvailable,
    required super.screenAudioVolume,
    required super.screenAudioMuted,
    required super.deafened,
    required super.onToggleScreenAudio,
    required super.onScreenAudioVolumeChanged,
    required super.onFullscreen,
    required super.onClose,
    required super.onScreenSelected,
  });
}
