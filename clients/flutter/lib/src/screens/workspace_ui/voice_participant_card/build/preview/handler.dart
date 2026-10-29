import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceParticipantCardPreviewRenderer
    on WorkspaceVoiceParticipantCardContext {
  Widget renderVoiceParticipantCardPreview() {
    if (!hasScreen) {
      return AspectRatio(
        key: ValueKey('voice-participant-preview:$previewIdentity'),
        aspectRatio: 16 / 9,
        child: Container(
          color: GcColors.raised,
          alignment: Alignment.center,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context)
                  .scale(1)
                  .clamp(1.0, 2.0)
                  .toDouble();
              final icon = Icon(
                Icons.headphones_outlined,
                size: 16 * textScale,
                color: GcColors.textSecondary,
              );
              final label = MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.noScaling),
                child: Text(
                  'В голосовом канале',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GcColors.textSecondary,
                    fontSize: 13 * textScale,
                  ),
                ),
              );
              if (constraints.maxWidth < 320 || textScale > 1.35) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    SizedBox(height: 4 * textScale),
                    label,
                  ],
                );
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Flexible(child: label),
                ],
              );
            },
          ),
        ),
      );
    }

    return AspectRatio(
      key: ValueKey('voice-participant-preview:$previewIdentity'),
      aspectRatio: 16 / 9,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: 'Участник показывает экран',
        value: previewCaption,
        hint: 'Открыть демонстрацию экрана',
        onTap: onScreenTap,
        child: Material(
          color: Colors.black,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: onScreenTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewThumbnail case final thumbnail?)
                  Image.memory(
                    thumbnail,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _emptyPreview(),
                  )
                else
                  _emptyPreview(),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 82,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      previewCaption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: GcColors.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'ЭФИР',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyPreview() => Container(
    color: Colors.black,
    alignment: Alignment.center,
    child: const Icon(
      Icons.desktop_windows_outlined,
      size: 32,
      color: GcColors.textSecondary,
    ),
  );
}
