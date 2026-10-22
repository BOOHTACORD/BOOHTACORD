import '../../../../../widgets/local_video_presentation.dart';
import '../../fullscreen.dart';
import '../video_preview/handler.dart';
import '../header_controls/handler.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension PinnedScreenMiniPlayerFloatingSurfaceRenderer
    on WorkspacePinnedScreenMiniPlayerContext {
  Widget renderPinnedScreenMiniPlayerFloatingSurface(
    String name,
    bool hasAudio,
    RemoteParticipant? participant,
    int? screenVolume,
    VideoTrack? track,
    String? publicationSid,
    RemoteTrackPublication<RemoteTrack>? publication,
    ScreenVideoRendererOwner rendererOwner,
    ScreenViewerPublicationGeneration? miniGeneration,
    ScreenViewerPublicationGeneration? selectedGeneration,
    ScreenFullscreenSelection? selectedFullscreen,
  ) => LocalVideoPresentation(
    generation: '$identity:${publicationSid ?? 'unknown'}',
    builder: (context, paused, toggleVideo) => LayoutBuilder(
      builder: (context, constraints) {
        final short =
            constraints.hasBoundedHeight && constraints.maxHeight < 120;
        return Material(
          color: GcColors.surface,
          elevation: 4,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: GcColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              renderPinnedScreenMiniPlayerHeaderControls(
                context,
                name,
                hasAudio,
                participant,
                screenVolume,
                paused: paused,
                toggleVideo: toggleVideo,
                singleLine: short,
                expand:
                    track == null ||
                        publicationSid == null ||
                        onFullscreenSelectionChanged == null ||
                        fullscreenSelection != null
                    ? null
                    : () {
                        if (paused) toggleVideo();
                        unawaited(
                          openPinnedScreenFullscreen(
                            onStopWatching: onStopWatching,
                            context: context,
                            state: state,
                            identity: identity,
                            name: name,
                            publicationSid: publicationSid,
                            track: track,
                            onSelectionChanged: onFullscreenSelectionChanged!,
                          ),
                        );
                      },
              ),
              if (!short)
                Flexible(
                  fit: FlexFit.loose,
                  child: paused
                      ? const AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ColoredBox(
                            color: Colors.black,
                            child: Center(
                              child: Text(
                                'Видео на паузе',
                                style: TextStyle(color: GcColors.muted),
                              ),
                            ),
                          ),
                        )
                      : renderPinnedScreenMiniPlayerVideoPreview(
                          track,
                          publicationSid,
                          participant,
                          publication,
                          rendererOwner,
                          miniGeneration,
                          selectedGeneration,
                          selectedFullscreen,
                        ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
