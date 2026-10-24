import '../../native_bindings.dart';

abstract class WorkspaceVoiceScreenViewerContext extends StatelessWidget {
  const WorkspaceVoiceScreenViewerContext({
    super.key,
    required this.state,
    required this.track,
    required this.rendererOwner,
    required this.publisherName,
    required this.screens,
    required this.selectedIdentity,
    required this.viewerGeneration,
    required this.onFirstFrameRendered,
    required this.localScreenAvailable,
    required this.showingLocalScreen,
    required this.receiverTrack,
    required this.sourceTrackName,
    required this.localName,
    required this.localMuted,
    required this.localSpeaking,
    required this.participants,
    required this.screenAudioAvailable,
    required this.screenAudioVolume,
    required this.screenAudioMuted,
    required this.deafened,
    required this.onToggleScreenAudio,
    required this.onScreenAudioVolumeChanged,
    required this.onFullscreen,
    required this.onClose,
    required this.onScreenSelected,
  });
  final AppState state;
  final VideoTrack track;
  final ScreenVideoRendererOwner rendererOwner;
  final String publisherName;
  final List<RemoteParticipant> screens;
  final String? selectedIdentity;
  final Object viewerGeneration;
  final VoidCallback? onFirstFrameRendered;
  final bool localScreenAvailable;
  final bool showingLocalScreen;
  final RemoteVideoTrack? receiverTrack;
  final String? sourceTrackName;
  final String localName;
  final bool localMuted;
  final bool localSpeaking;
  final List<RemoteParticipant> participants;
  final bool screenAudioAvailable;
  final int? screenAudioVolume;
  final bool screenAudioMuted;
  final bool deafened;
  final VoidCallback? onToggleScreenAudio;
  final ValueChanged<int>? onScreenAudioVolumeChanged;
  final VoidCallback onFullscreen;
  final VoidCallback onClose;
  final ValueChanged<String?> onScreenSelected;
  Widget get workspaceAudioControls;
  Widget? get workspaceStreamRail;
}
