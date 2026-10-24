import '../native_bindings.dart';
import '../../screen_fullscreen_route.dart';
import '../voice_viewer_participants_menu.dart';

Future<void> openPinnedScreenFullscreen({
  required BuildContext context,
  required AppState state,
  required VoidCallback onStopWatching,
  required String identity,
  required String name,
  required String publicationSid,
  required VideoTrack track,
  required ValueChanged<ScreenFullscreenSelection?> onSelectionChanged,
}) {
  final generation = ScreenViewerPublicationGeneration(
    participantIdentity: identity,
    publicationSid: publicationSid,
  );
  return presentScreenFullscreen(
    context: context,
    state: state,
    publisherIdentity: identity,
    generation: generation,
    onSelectionChanged: onSelectionChanged,
    content: (lease, target) => ScreenFullscreenOverlay(
      publisherName: name,
      participantsOverlay: VoiceViewerParticipantsMenu(state: state),
      onClose: () => Navigator.of(target).pop(),
      onStopWatching: () {
        Navigator.of(target).pop();
        onStopWatching();
      },
      video: ScreenFullscreenRendererGate(
        lease: lease,
        child: ScreenFrameGate(
          generation: generation,
          recoveryExhausted: state.voice.remoteScreenViewerRecoveryExhausted,
          onRecoveryRetry: state.voice.retryRemoteScreenViewerRecovery,
          onFirstFrame: () => state.voice.markRemoteScreenFirstFrameRendered(
            identity,
            publicationSid,
          ),
          builder: (_, frame) => VideoTrackRenderer(
            track,
            fit: VideoViewFit.contain,
            renderMode: VideoRenderMode.auto,
            onFirstFrameRendered: frame,
          ),
        ),
      ),
    ),
  );
}
