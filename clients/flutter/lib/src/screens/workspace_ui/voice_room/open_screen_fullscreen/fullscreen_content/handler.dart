import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceRoomFullscreenContentRenderer on WorkspaceVoiceRoomStateContext {
  ScreenFullscreenOverlay renderVoiceRoomFullscreenContent(
    String publisherName,
    Object viewerGeneration,
    void Function()? onFirstFrameRendered,
    bool showingLocalScreen,
    ScreenFullscreenRendererLease rendererLease,
    VideoTrack track,
    BuildContext dialogContext,
  ) => ScreenFullscreenOverlay(
    publisherName: publisherName,
    video: ScreenVideoRendererSlot(
      surface: ScreenVideoRendererSurface.fullscreen,
      owner: ScreenVideoRendererOwner.fullscreen,
      isSelectedPublication: true,
      isFullscreenPublication: true,
      child: ScreenFrameGate(
        generation: viewerGeneration,
        onFirstFrame: onFirstFrameRendered,
        telemetry: showingLocalScreen
            ? null
            : widget.state.api.transport.session.telemetry,
        recoveryExhausted:
            !showingLocalScreen &&
            widget.state.voice.remoteScreenViewerRecoveryExhausted,
        onRecoveryRetry: showingLocalScreen
            ? null
            : widget.state.voice.retryRemoteScreenViewerRecovery,
        builder: (context, onFirstFrameRendered) =>
            ScreenFullscreenRendererGate(
              lease: rendererLease,
              child: VideoTrackRenderer(
                track,
                renderMode: VideoRenderMode.auto,
                onFirstFrameRendered: () {
                  if (showingLocalScreen) {
                    debugPrint(
                      '[screen-preview] local_renderer=first_swap_buffers',
                    );
                  } else {
                    debugPrint('[screen-viewer] remote_renderer=first_frame');
                  }
                  onFirstFrameRendered();
                },
              ),
            ),
      ),
    ),
    onClose: () => Navigator.of(dialogContext).pop(),
    onStopWatching: showingLocalScreen
        ? null
        : () {
            Navigator.of(dialogContext).pop();
            widget.onSelectScreen('');
          },
  );
}
