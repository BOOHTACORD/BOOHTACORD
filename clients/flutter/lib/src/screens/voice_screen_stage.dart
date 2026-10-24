import 'package:flutter/material.dart';

import '../features/screen/capabilities/local_track_status.dart';
import '../features/screen/stage/label.dart';
import '../widgets/screen_viewer_action_layer.dart';

class VoiceScreenStage extends StatelessWidget {
  const VoiceScreenStage({
    super.key,
    required this.video,
    required this.publisherName,
    required this.avatarName,
    this.isLocal = false,
    this.reservedTrailingWidth = 0,
    this.overlays = const [],
  });

  final Widget video;
  final String publisherName;
  final String avatarName;
  final bool isLocal;
  final double reservedTrailingWidth;
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth <= 720;
      final inset = compact ? 8.0 : 16.0;
      final labelHeight = compact ? 28.0 : 40.0;
      final label = VoiceScreenStageLabel(
        publisherName: publisherName,
        avatarName: avatarName,
        isLocal: isLocal,
        compact: compact,
        height: labelHeight,
        maxWidth: (constraints.maxWidth - inset * 2 - reservedTrailingWidth)
            .clamp(0, double.infinity)
            .toDouble(),
      );

      return Container(
        key: const ValueKey('voice-screen-stage'),
        color: const Color(0xFF050608),
        child: ClipRRect(
          key: const ValueKey('voice-screen-stage-clip'),
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: video),
              Positioned(
                key: const ValueKey('voice-screen-stage-label-position'),
                left: inset,
                top: inset,
                child: label,
              ),
              if (isLocal)
                Positioned(
                  key: const ValueKey('local-screen-track-status-position'),
                  left: inset,
                  bottom: inset,
                  child: const LocalScreenTrackStatus(),
                ),
              if (overlays.isNotEmpty)
                Positioned.fill(
                  child: ScreenViewerActionLayer(actions: overlays),
                ),
            ],
          ),
        ),
      );
    },
  );
}
