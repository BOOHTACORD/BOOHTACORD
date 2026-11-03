import 'package:flutter/material.dart';

import '../../features/voice/disconnect_notice/model.dart';
import '../../theme.dart';

class VoiceManualJoinActions extends StatelessWidget {
  const VoiceManualJoinActions({
    super.key,
    required this.joining,
    required this.leaving,
    required this.admissionClosed,
    required this.onJoin,
    required this.onListen,
    this.notice,
  });
  final bool joining, leaving, admissionClosed;
  final VoidCallback onJoin, onListen;
  final VoiceDisconnectNotice? notice;
  @override
  Widget build(BuildContext context) {
    final disabled =
        joining ||
        leaving ||
        admissionClosed ||
        notice?.reconnectAllowed == false;
    final compact = MediaQuery.sizeOf(context).width <= 600;
    final primaryButton = SizedBox(
      width: compact ? double.infinity : null,
      child: FilledButton(
        onPressed: disabled ? null : onJoin,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GcRadii.md),
          ),
        ),
        child: Text(
          admissionClosed
              ? 'Вход временно закрыт'
              : joining
              ? 'Подключаемся…'
              : 'Войти',
        ),
      ),
    );
    final listenerButton = SizedBox(
      width: compact ? double.infinity : null,
      child: OutlinedButton(
        onPressed: disabled ? null : onListen,
        style: OutlinedButton.styleFrom(
          foregroundColor: GcColors.textSecondary,
          backgroundColor: GcColors.raised,
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: GcColors.control),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GcRadii.md),
          ),
        ),
        child: const Text('Без микрофона'),
      ),
    );
    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [primaryButton, const SizedBox(height: 8), listenerButton],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(child: primaryButton),
          const SizedBox(width: 8),
          Expanded(child: listenerButton),
        ],
      ),
    );
  }
}
