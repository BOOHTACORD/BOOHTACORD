import '../../../voice_screen_viewer/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceRoomScreenViewerRenderer on WorkspaceVoiceRoomStateContext {
  WorkspaceVoiceScreenViewer renderVoiceRoomScreenViewer(
    AppState state,
    VideoTrack viewerTrack,
    ScreenVideoRendererOwner rendererOwner,
    String? selectedName,
    List<RemoteParticipant> screens,
    Object? viewerGeneration,
    RemoteParticipant? selectedScreen,
    RemoteTrackPublication<RemoteTrack>? selectedScreenPublication,
    VideoTrack? localScreenTrack,
    bool showingLocalScreen,
    VideoTrack? selectedTrack,
    LocalTrackPublication<LocalTrack>? localScreenPublication,
    Room? room,
    List<RemoteParticipant> participants,
    RemoteTrackPublication<RemoteAudioTrack>? selectedAudioPublication,
  ) => WorkspaceVoiceScreenViewer(
    state: state,
    track: viewerTrack,
    rendererOwner: rendererOwner,
    publisherName: selectedName!,
    screens: screens,
    selectedIdentity: widget.selectedScreenIdentity,
    viewerGeneration: viewerGeneration!,
    onFirstFrameRendered:
        selectedScreen == null || selectedScreenPublication == null
        ? null
        : () => state.voice.markRemoteScreenFirstFrameRendered(
            selectedScreen.identity,
            selectedScreenPublication.sid,
          ),
    localScreenAvailable: localScreenTrack != null,
    showingLocalScreen: showingLocalScreen,
    receiverTrack: selectedTrack is RemoteVideoTrack ? selectedTrack : null,
    sourceTrackName: showingLocalScreen
        ? localScreenPublication?.name
        : selectedScreenPublication?.name,
    localName: state.profile?.displayName.trim().isNotEmpty == true
        ? state.profile!.displayName
        : 'Вы',
    localMuted: state.microphoneMuted,
    localSpeaking: room?.localParticipant?.isSpeaking ?? false,
    participants: participants,
    screenAudioAvailable:
        !showingLocalScreen && selectedAudioPublication != null,
    screenAudioVolume:
        showingLocalScreen ||
            selectedAudioPublication == null ||
            selectedScreen == null
        ? null
        : state.screenShareVolume(selectedScreen),
    screenAudioMuted:
        selectedScreen != null && state.screenShareAudioMuted(selectedScreen),
    deafened: state.deafened,
    onToggleScreenAudio: selectedScreen == null
        ? null
        : () => unawaited(state.toggleScreenShareAudio(selectedScreen)),
    onScreenAudioVolumeChanged: selectedScreen == null || showingLocalScreen
        ? null
        : (level) =>
              unawaited(state.setScreenShareVolume(selectedScreen, level)),
    onFullscreen: () => workspaceOpenScreenFullscreen(
      track: viewerTrack,
      publisherName: selectedName,
      publisherIdentity: selectedScreen?.identity,
      viewerGeneration: viewerGeneration,
      onFirstFrameRendered:
          selectedScreen == null || selectedScreenPublication == null
          ? null
          : () => state.voice.markRemoteScreenFirstFrameRendered(
              selectedScreen.identity,
              selectedScreenPublication.sid,
            ),
      showingLocalScreen: showingLocalScreen,
    ),
    onClose: () => widget.onSelectScreen(''),
    onScreenSelected: widget.onSelectScreen,
  );
}
