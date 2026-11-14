import 'feed.dart';
import 'projection.dart';
import 'roster_projection.dart';
import 'live_members.dart';
import '../../../../models.dart';
import '../../lifecycle/controller.dart';
import '../../roster_state/controller.dart';

VoiceOverlayFeed createCurrentVoiceOverlayFeed({
  required VoiceController voice,
  required VoiceRosterController roster,
  required String? Function() readAccountId,
}) {
  VoiceOverlayFeed? feed;
  feed = VoiceOverlayFeed(
    sources: [voice, roster],
    project: (enabled, onlySpeakers) => currentVoiceOverlaySnapshot(
      voice: voice,
      roster: roster,
      accountId: readAccountId(),
      settings: VoiceOverlaySettings(
        enabled: enabled,
        onlySpeakers: onlySpeakers,
        maxParticipants: feed?.maxParticipants ?? 8,
      ),
    ),
  );
  return feed;
}

VoiceOverlaySnapshot currentVoiceOverlaySnapshot({
  required VoiceController voice,
  required VoiceRosterController roster,
  required String? accountId,
  required VoiceOverlaySettings settings,
}) {
  final channelId = voice.voiceChannel?.id;
  final room = voice.room;
  final members = roster.voiceRosters;
  final status = switch (voice.voicePhase) {
    VoicePhase.connected ||
    VoicePhase.listener => VoiceOverlayVoiceStatus.connected,
    VoicePhase.reconnecting => VoiceOverlayVoiceStatus.reconnecting,
    _ => VoiceOverlayVoiceStatus.disconnected,
  };
  final speaking = <String>{};
  if (room != null && status == VoiceOverlayVoiceStatus.connected) {
    if (accountId != null &&
        room.localParticipant?.isSpeaking == true &&
        !voice.microphoneMuted) {
      speaking.add(accountId);
    }
    for (final participant in room.remoteParticipants.values) {
      final metadata = participant.metadata;
      if (participant.isSpeaking &&
          metadata != null &&
          metadata.startsWith('account:')) {
        speaking.add(metadata.substring('account:'.length));
      }
    }
  }
  final activeRoster = members
      ?.where((entry) => entry.channelId == channelId)
      .firstOrNull;
  final projectedRoster = room == null
      ? const <VoiceRosterMember>[]
      : liveOverlayMembers(
          room,
          activeRoster,
          accountId,
          voice.microphoneMuted,
          deafened: voice.deafened,
        );
  return projectVoiceOverlayRoster(
    settings: settings,
    voiceChannelId: room == null ? null : channelId,
    rosterChannelId: room == null ? null : channelId,
    voiceStatus: status,
    roster: projectedRoster,
    speakingAccountIds: speaking,
    maxParticipants: settings.maxParticipants,
  );
}
