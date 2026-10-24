import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceScreenViewerScreenStageRenderer
    on WorkspaceVoiceScreenViewerContext {
  VoiceScreenStage renderVoiceScreenViewerScreenStage(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final bottomActions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        if (!showingLocalScreen && screenAudioAvailable)
          SizedBox(width: 220, child: workspaceAudioControls),
        if (showingLocalScreen)
          compact
              ? IconButton.filledTonal(
                  tooltip: 'Вернуться к участникам',
                  onPressed: onClose,
                  icon: const Icon(Icons.people_outline),
                )
              : TextButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.people_outline),
                  label: const Text('К участникам'),
                )
        else
          compact
              ? IconButton.filled(
                  tooltip: 'Прекратить просмотр',
                  style: IconButton.styleFrom(
                    backgroundColor: GcColors.dangerBackground,
                    foregroundColor: GcColors.danger,
                  ),
                  onPressed: onClose,
                  icon: const Icon(Icons.stop_circle_outlined),
                )
              : TextButton.icon(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    foregroundColor: GcColors.danger,
                    backgroundColor: GcColors.dangerBackground,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Прекратить просмотр'),
                ),
        compact
            ? IconButton.filledTonal(
                tooltip: 'Развернуть демонстрацию на весь экран',
                onPressed: onFullscreen,
                icon: const Icon(Icons.fullscreen_outlined),
              )
            : FilledButton.tonalIcon(
                onPressed: onFullscreen,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.fullscreen_outlined, size: 18),
                label: const Text('Развернуть'),
              ),
      ],
    );

    return VoiceScreenStage(
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
      bottomActions: bottomActions,
    );
  }
}
