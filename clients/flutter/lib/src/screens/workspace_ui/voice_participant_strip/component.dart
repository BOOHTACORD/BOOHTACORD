import '../participant_member/component.dart';
import '../participant_muted/component.dart';
import '../participant_name/component.dart';
import '../voice_participant_account_id/component.dart';
import '../voice_strip_person/component.dart';
import '../native_bindings.dart';

class WorkspaceVoiceParticipantStrip extends StatelessWidget {
  const WorkspaceVoiceParticipantStrip({
    super.key,
    required this.state,
    required this.localName,
    required this.localAvatarUrl,
    required this.localMuted,
    required this.localSpeaking,
    required this.participants,
    this.showAudience = false,
    this.watcherAccountIds = const [],
    this.watcherLabel = 'Смотрит трансляцию',
  });

  final AppState state;
  final String localName;
  final String? localAvatarUrl;
  final bool localMuted;
  final bool localSpeaking;
  final List<RemoteParticipant> participants;
  final bool showAudience;
  final List<String> watcherAccountIds;
  final String watcherLabel;

  @override
  Widget build(BuildContext context) {
    final watcherIds = watcherAccountIds.map((id) => id.toLowerCase()).toSet();
    final compactLabels = MediaQuery.textScalerOf(context).scale(12) > 16;
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      decoration: const BoxDecoration(
        color: GcColors.sidebar,
        border: Border(top: BorderSide(color: GcColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: compactLabels
                ? 96
                : showAudience
                ? 120
                : 110,
            child: compactLabels
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label:
                            'Участники: ${participants.length + 1} в комнате',
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              const Icon(Icons.people_outline, size: 18),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${participants.length + 1}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showAudience) ...[
                        const SizedBox(height: 3),
                        Semantics(
                          liveRegion: true,
                          label:
                              'Зрители трансляции: ${watcherAccountIds.length}',
                          child: ExcludeSemantics(
                            child: Row(
                              children: [
                                const Icon(Icons.visibility_outlined, size: 18),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${watcherAccountIds.length}',
                                    key: const ValueKey(
                                      'screen-viewer-audience-count',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Участники',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${participants.length + 1} в комнате',
                        style: const TextStyle(
                          color: GcColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      if (showAudience) ...[
                        const SizedBox(height: 3),
                        Semantics(
                          liveRegion: true,
                          label:
                              'Зрители трансляции: ${watcherAccountIds.length}',
                          child: ExcludeSemantics(
                            child: Text(
                              'Зрители · ${watcherAccountIds.length}',
                              key: const ValueKey(
                                'screen-viewer-audience-count',
                              ),
                              style: const TextStyle(
                                color: GcColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                WorkspaceVoiceStripPerson(
                  state: state,
                  name: localName,
                  avatarUrl: localAvatarUrl,
                  muted: localMuted,
                  speaking: localSpeaking,
                  microphoneUnavailable: state.microphoneUnavailable,
                  deafened: state.deafened,
                  screenSharing:
                      state.screenSharePhase == ScreenSharePhase.sharing,
                  watchingScreen: watcherIds.contains(
                    state.user?.accountId.toLowerCase(),
                  ),
                  watcherLabel: watcherLabel,
                ),
                for (final participant in participants)
                  WorkspaceVoiceStripPerson(
                    state: state,
                    name: workspaceParticipantName(participant),
                    avatarUrl: workspaceParticipantMember(
                      state,
                      participant,
                    )?.avatarUrl,
                    muted: workspaceParticipantMuted(participant),
                    speaking: participant.isSpeaking,
                    screenSharing: participant.videoTrackPublications.any(
                      (publication) =>
                          publication.source == TrackSource.screenShareVideo &&
                          !publication.muted,
                    ),
                    watchingScreen: watcherIds.contains(
                      workspaceVoiceParticipantAccountId(participant)
                          ?.toLowerCase(),
                    ),
                    watcherLabel: watcherLabel,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
