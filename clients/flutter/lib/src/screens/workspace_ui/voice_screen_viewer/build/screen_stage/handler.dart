import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceScreenViewerScreenStageRenderer
    on WorkspaceVoiceScreenViewerContext {
  VoiceScreenStage renderVoiceScreenViewerScreenStage() => VoiceScreenStage(
    publisherName: publisherName,
    avatarName: showingLocalScreen ? localName : publisherName,
    isLocal: showingLocalScreen,
    reservedTrailingWidth: selectedIdentity == null ? 124 : 172,
    video: ScreenVideoRendererSlot(
      surface: ScreenVideoRendererSurface.stage,
      owner: rendererOwner,
      isSelectedPublication: true,
      isFullscreenPublication: false,
      child: ScreenFrameGate(
        generation: viewerGeneration,
        onFirstFrame: onFirstFrameRendered,
        telemetry: showingLocalScreen
            ? null
            : state.api.transport.session.telemetry,
        recoveryExhausted:
            !showingLocalScreen &&
            state.voice.remoteScreenViewerRecoveryExhausted,
        onRecoveryRetry: showingLocalScreen
            ? null
            : state.voice.retryRemoteScreenViewerRecovery,
        waitingMessage:
            showingLocalScreen && state.screenCapturedContentVisible == false
            ? 'Android скрыл выбранное приложение. Вернитесь в него или выберите весь экран.'
            : null,
        builder: (context, onFirstFrameRendered) => VideoTrackRenderer(
          track,
          key: ValueKey(viewerGeneration),
          renderMode: VideoRenderMode.auto,
          onFirstFrameRendered: () {
            if (showingLocalScreen) {
              debugPrint('[screen-preview] local_renderer=first_swap_buffers');
            } else {
              debugPrint('[screen-viewer] remote_renderer=first_frame');
            }
            onFirstFrameRendered();
          },
        ),
      ),
    ),
    overlays: [
      Positioned(
        right: 76,
        top: 28,
        child: IconButton.filledTonal(
          tooltip: 'Развернуть демонстрацию на весь экран',
          onPressed: onFullscreen,
          icon: const Icon(Icons.fullscreen_outlined),
        ),
      ),
      if (selectedIdentity != null)
        Positioned(
          right: 124,
          top: 28,
          child: IconButton.filledTonal(
            tooltip: pinned
                ? 'Открепить демонстрацию'
                : 'Закрепить демонстрацию',
            onPressed: onTogglePin,
            icon: Icon(
              pinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
            ),
          ),
        ),
      Positioned(
        right: 28,
        top: 28,
        child: IconButton.filledTonal(
          tooltip: showingLocalScreen
              ? 'Вернуться к участникам'
              : 'Остановить просмотр',
          onPressed: onClose,
          icon: const Icon(Icons.close_fullscreen_outlined),
        ),
      ),
    ],
  );
}
