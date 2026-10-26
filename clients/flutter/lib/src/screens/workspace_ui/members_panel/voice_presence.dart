import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/phase.dart';
import 'package:boohtacord_desktop/src/models.dart';

class GuildMemberVoiceStatus {
  const GuildMemberVoiceStatus({
    required this.channelName,
    required this.screenSharing,
  });

  final String channelName;
  final bool screenSharing;
}

GuildMemberVoiceStatus? guildMemberVoiceStatus(
  AppState state,
  String accountId,
) {
  if (state.voiceRoster.phase != VoiceRosterPhase.fresh) return null;
  final rosters = state.voiceRosters;
  final topology = state.topology;
  if (rosters == null || topology == null) return null;

  final channelNames = {
    for (final category in topology.categories)
      for (final channel in category.channels)
        if (channel.kind == ChannelKind.voice) channel.id: channel.name,
  };
  final matches = [
    for (final roster in rosters)
      for (final member in roster.participants)
        if (member.accountId == accountId &&
            channelNames.containsKey(roster.channelId))
          GuildMemberVoiceStatus(
            channelName: channelNames[roster.channelId]!,
            screenSharing: member.screenSharing,
          ),
  ];
  return matches.length == 1 ? matches.single : null;
}
