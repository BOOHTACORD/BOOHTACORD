import 'package:flutter/material.dart';

import '../theme.dart';
import '../features/voice/viewer_pending/presentation.dart';
import 'voice_screen_selection_rail.dart';
import 'voice_viewer_layout.dart';

class VoiceScreenEndedView extends StatelessWidget {
  const VoiceScreenEndedView({
    super.key,
    required this.choices,
    required this.participants,
    required this.onScreenSelected,
    required this.onReturnToParticipants,
    this.connecting = false,
    this.recoveryExhausted = false,
    this.onRecoveryRetry,
  });

  final List<VoiceScreenChoice> choices;
  final Widget participants;
  final ValueChanged<String?> onScreenSelected;
  final VoidCallback onReturnToParticipants;
  final bool connecting;
  final bool recoveryExhausted;
  final VoidCallback? onRecoveryRetry;

  @override
  Widget build(BuildContext context) => VoiceViewerLayout(
    stage: ColoredBox(
      color: GcColors.streamCanvas,
      child: ScreenViewerPendingStatus(
        connecting: connecting,
        recoveryExhausted: recoveryExhausted,
        onRecoveryRetry: onRecoveryRetry,
      ),
    ),
    diagnostics: const SizedBox.shrink(),
    streamRail: choices.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Демонстрации в канале',
                  style: TextStyle(
                    color: GcColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                VoiceScreenSelectionRail(
                  choices: choices,
                  onSelected: onScreenSelected,
                ),
              ],
            ),
          ),
    bottomActions: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Невыбранные демонстрации не воспроизводятся.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
          TextButton.icon(
            onPressed: onReturnToParticipants,
            icon: const Icon(Icons.people_outline),
            label: const Text('К участникам'),
          ),
        ],
      ),
    ),
    participants: participants,
  );
}
