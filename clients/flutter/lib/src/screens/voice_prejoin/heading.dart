import 'package:flutter/material.dart';

import '../../theme.dart';

class VoicePrejoinHeading extends StatelessWidget {
  const VoicePrejoinHeading({super.key, required this.joining});
  final bool joining;
  @override
  Widget build(BuildContext context) {
    final title = joining ? 'Входим в голос…' : 'Войти в голос';
    return Column(
      children: [
        Container(
          key: const ValueKey('voice-prejoin-icon'),
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: GcColors.raised,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(BorderSide(color: GcColors.control)),
          ),
          child: const Icon(
            Icons.mic_none_outlined,
            size: 28,
            color: GcColors.accentText,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          liveRegion: true,
          label: title,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
