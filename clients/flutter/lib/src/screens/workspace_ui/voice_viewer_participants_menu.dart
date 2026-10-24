import 'dart:math' as math;

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import 'participant_member/component.dart';
import 'participant_muted/component.dart';
import 'participant_name/component.dart';
import 'voice_participant_account_id/component.dart';
import 'voice_strip_person/component.dart';

/// Opens the active voice roster over the screen viewer instead of reserving
/// a fixed-height row below the video stage.
class VoiceViewerParticipantsMenu extends StatefulWidget {
  const VoiceViewerParticipantsMenu({
    super.key,
    required this.state,
    this.showingLocalScreen = false,
  });

  final AppState state;
  final bool showingLocalScreen;

  @override
  State<VoiceViewerParticipantsMenu> createState() =>
      _VoiceViewerParticipantsMenuState();
}

class _VoiceViewerParticipantsMenuState
    extends State<VoiceViewerParticipantsMenu> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final remoteParticipants =
        state.room?.remoteParticipants.values.toList(growable: false) ??
        const <RemoteParticipant>[];
    final memberCount = remoteParticipants.length + 1;
    final watcherAccountIds = widget.showingLocalScreen
        ? state.voice.ownerScreenViewerAccountIds
        : state.voice.screenViewerAccountIds;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = math.max(120.0, screenWidth - 24);
    final panelWidth = math.min(
      maxWidth,
      math.min(560.0, math.max(216.0, memberCount * 168.0 + 24)),
    );
    final triggerWidth = math.min(panelWidth, 260.0);
    final watchingIds = watcherAccountIds.map((id) => id.toLowerCase()).toSet();
    final localName = state.profile?.displayName.trim().isNotEmpty == true
        ? state.profile!.displayName
        : 'Вы';
    final watcherLabel = widget.showingLocalScreen
        ? 'Смотрит вашу трансляцию'
        : 'Смотрит эту трансляцию';

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: Offset(triggerWidth - panelWidth, 8),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(GcColors.sidebar),
        elevation: const WidgetStatePropertyAll(12),
        maximumSize: WidgetStatePropertyAll(Size(maxWidth, 280)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            side: const BorderSide(color: GcColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: panelWidth,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Участники',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$memberCount в комнате',
                            style: const TextStyle(
                              color: GcColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Semantics(
                            liveRegion: true,
                            label:
                                'Зрители трансляции: ${watcherAccountIds.length}',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.visibility_outlined,
                                  size: 14,
                                  color: GcColors.accentText,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Зрители · ${watcherAccountIds.length}',
                                  key: const ValueKey(
                                    'screen-viewer-audience-count',
                                  ),
                                  style: const TextStyle(
                                    color: GcColors.accentText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть панель участников',
                      onPressed: _controller.close,
                      icon: const Icon(Icons.close, size: 18),
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: Semantics(
                    label: 'Состав голосового канала',
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        WorkspaceVoiceStripPerson(
                          key: const ValueKey('viewer-panel-self'),
                          state: state,
                          name: localName,
                          avatarUrl: state.profile?.avatarUrl,
                          muted: state.microphoneMuted,
                          speaking:
                              state.room?.localParticipant?.isSpeaking ?? false,
                          microphoneUnavailable: state.microphoneUnavailable,
                          deafened: state.deafened,
                          screenSharing:
                              state.screenSharePhase ==
                              ScreenSharePhase.sharing,
                          watchingScreen: watchingIds.contains(
                            state.user?.accountId.toLowerCase(),
                          ),
                          watcherLabel: watcherLabel,
                        ),
                        for (final participant in remoteParticipants)
                          WorkspaceVoiceStripPerson(
                            key: ValueKey(
                              'viewer-panel-${participant.identity}',
                            ),
                            state: state,
                            name: workspaceParticipantName(participant),
                            avatarUrl: workspaceParticipantMember(
                              state,
                              participant,
                            )?.avatarUrl,
                            muted: workspaceParticipantMuted(participant),
                            speaking: participant.isSpeaking,
                            screenSharing: participant.videoTrackPublications
                                .any(
                                  (publication) =>
                                      publication.source ==
                                          TrackSource.screenShareVideo &&
                                      !publication.muted,
                                ),
                            watchingScreen: watchingIds.contains(
                              workspaceVoiceParticipantAccountId(participant)
                                  ?.toLowerCase(),
                            ),
                            watcherLabel: watcherLabel,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => SizedBox(
        width: triggerWidth,
        height: 44,
        child: Tooltip(
          message: 'Участники трансляции',
          child: OutlinedButton.icon(
            onPressed: controller.isOpen ? controller.close : controller.open,
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              backgroundColor: GcColors.sidebar.withValues(alpha: .94),
              foregroundColor: GcColors.text,
              side: BorderSide(
                color: controller.isOpen ? GcColors.accent : GcColors.border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.people_outline, size: 16),
            label: Text(
              'Участники · $memberCount · Зрители · ${watcherAccountIds.length}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}
