import 'category_header/handler.dart';
import '../../channel_row/component.dart';
import '../../voice_navigation_members/component.dart';
import '../../voice_roster_navigation_members/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceCategoryStateBuildBinding on WorkspaceCategoryStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceCategoryStateBuild(context);
  }
}

extension WorkspaceCategoryStateBuildAction on WorkspaceCategoryStateContext {
  Widget executeWorkspaceCategoryStateBuild(BuildContext context) {
    final category = widget.category;
    final state = widget.state;
    final disclosureLabel =
        '${workspaceExpanded ? 'Свернуть' : 'Развернуть'} раздел ${category.name}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          renderCategoryCategoryHeader(category, disclosureLabel, state),
          if (workspaceExpanded) ...[
            if (category.channels.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'Нет каналов',
                  style: TextStyle(color: GcColors.muted, fontSize: 12),
                ),
              ),
            for (final channel in category.channels) ...[
              Builder(
                builder: (context) {
                  final room = state.voiceChannel?.id == channel.id
                      ? state.room
                      : null;
                  final localParticipant = room?.localParticipant;
                  final roster = state.voiceRosters
                      ?.where((item) => item.channelId == channel.id)
                      .firstOrNull;
                  final memberCount = localParticipant == null
                      ? roster?.participants.length
                      : room!.remoteParticipants.length + 1;
                  return Column(
                    children: [
                      WorkspaceChannelRow(
                        state: state,
                        channel: channel,
                        selected: state.selectedChannel?.id == channel.id,
                        voiceConnected: state.voiceChannel?.id == channel.id,
                        voiceParticipantCount: memberCount,
                        favorite: widget.favoriteIds.contains(channel.id),
                        onFavoriteChanged: widget.onFavoriteChanged == null
                            ? null
                            : (favorite) =>
                                  widget.onFavoriteChanged!(channel, favorite),
                        onTap: () {
                          if (widget.onChannelSelected != null &&
                              channel.kind == ChannelKind.voice) {
                            state.enterVoiceChannel(channel);
                          } else {
                            state.selectChannel(channel);
                          }
                          widget.onChannelSelected?.call();
                        },
                      ),
                      if (localParticipant != null)
                        WorkspaceVoiceNavigationMembers(
                          state: state,
                          localParticipant: localParticipant,
                          remoteParticipants: room!.remoteParticipants.values,
                        )
                      else if (channel.kind == ChannelKind.voice &&
                          roster != null &&
                          roster.participants.isNotEmpty)
                        WorkspaceVoiceRosterNavigationMembers(
                          roster: roster,
                          state: state,
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
