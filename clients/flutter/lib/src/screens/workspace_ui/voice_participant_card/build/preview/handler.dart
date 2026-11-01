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
                    errorBuilder: (_, _, _) => _previewPending(),
                  )
                else
                  _previewPending(),
                if (previewCaption.trim().isNotEmpty)
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, left: 10),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const textStyle = TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          );
                          final effectiveTextStyle = DefaultTextStyle.of(
                            context,
                          ).style.merge(textStyle);
                          final maxWidth = (constraints.maxWidth - 120)
                              .clamp(0.0, constraints.maxWidth)
                              .toDouble();
                          final textPainter = TextPainter(
                            text: TextSpan(
                              text: previewCaption,
                              style: effectiveTextStyle,
                            ),
                            maxLines: 1,
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          )..layout();
                          final captionWidth = (textPainter.width + 14)
                              .clamp(0.0, maxWidth)
                              .toDouble();
                          textPainter.dispose();
                          return ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: SizedBox(
                              width: captionWidth,
                              child: Container(
                                key: const ValueKey(
                                  'participant-screen-preview-caption',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  previewCaption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: effectiveTextStyle,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    key: const ValueKey('participant-screen-preview-live'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: GcColors.danger),
                        SizedBox(width: 5),
                        Text(
                          'ЭФИР',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (previewThumbnail != null)
                  const Center(
                    child: DecoratedBox(
                      key: ValueKey('participant-screen-preview-play'),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(15, 16, 22, 0.34),
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(
                            color: Color.fromRGBO(255, 255, 255, 0.76),
                          ),
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 36,
                        child: Center(
                          child: Icon(
                            Icons.play_arrow,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewPending() => Container(
    color: Colors.black,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: constraints.maxWidth,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.desktop_windows_outlined,
                size: 32,
                color: GcColors.textSecondary,
              ),
              SizedBox(height: 8),
              Text(
                'Трансляция идёт',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Предпросмотр скоро появится',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GcColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
