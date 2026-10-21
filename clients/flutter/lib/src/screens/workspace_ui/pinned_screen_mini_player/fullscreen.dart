import '../native_bindings.dart';
import '../../screen_fullscreen_route.dart';

Future<void> openPinnedScreenFullscreen({
  required BuildContext context,
  required AppState state,
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
      onClose: () => Navigator.of(target).pop(),
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
