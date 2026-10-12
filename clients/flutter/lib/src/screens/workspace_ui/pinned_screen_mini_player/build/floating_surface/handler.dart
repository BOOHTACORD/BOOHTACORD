import '../video_preview/handler.dart';
import '../header_controls/handler.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension PinnedScreenMiniPlayerFloatingSurfaceRenderer
    on WorkspacePinnedScreenMiniPlayerContext {
  Material renderPinnedScreenMiniPlayerFloatingSurface(
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
  ) => Material(
    color: GcColors.surface,
    elevation: 16,
    shadowColor: const Color(0x70000000),
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: GcColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        renderPinnedScreenMiniPlayerHeaderControls(
          name,
          hasAudio,
          participant,
          screenVolume,
        ),
        Flexible(
          fit: FlexFit.loose,
          child: renderPinnedScreenMiniPlayerVideoPreview(
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
        if (hasAudio && screenVolume != null && participant != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.volume_down_outlined, size: 18),
                Expanded(
                  child: Semantics(
                    label: 'Громкость звука выбранной демонстрации',
                    child: Slider(
                      value: screenVolume.toDouble(),
                      min: 0,
                      max: 200,
                      divisions: 200,
                      semanticFormatterCallback: (value) =>
                          '${value.round()} процентов',
                      onChanged: state.deafened
                          ? null
                          : (value) => unawaited(
                              state.setScreenShareVolume(
                                participant,
                                value.round(),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
