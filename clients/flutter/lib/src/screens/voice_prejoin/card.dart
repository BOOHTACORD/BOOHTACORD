import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/voice_disconnect/join_actions.dart';
import '../../widgets/voice_disconnect/notice.dart';
import 'surface.dart';
import 'heading.dart';
import 'roster_preview.dart';

class VoicePrejoinCard extends StatelessWidget {
  const VoicePrejoinCard({
    super.key,
    required this.state,
    required this.channel,
  });
  final AppState state;
  final GuildChannel channel;
  @override
  Widget build(BuildContext context) {
    return VoicePrejoinSurface(
      children: [
        VoicePrejoinHeading(joining: state.voicePhase == VoicePhase.joining),
        const SizedBox(height: 16),
        VoiceRosterPreview(state: state, channelId: channel.id, compact: true),
        if (state.voiceDisconnectNotice != null) ...[
          const SizedBox(height: 16),
          VoiceDisconnectNoticeView(notice: state.voiceDisconnectNotice!),
        ] else if (state.error != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF422830),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: GcColors.danger, fontSize: 13),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        VoiceManualJoinActions(
          joining: state.voicePhase == VoicePhase.joining,
          leaving: state.voicePhase == VoicePhase.leaving,
          admissionClosed: channel.admissionClosed,
          notice: state.voiceDisconnectNotice,
          onJoin: () => unawaited(state.joinVoice(channel)),
          onListen: () =>
              unawaited(state.joinVoice(channel, listenerOnly: true)),
        ),
      ],
    );
  }
}
