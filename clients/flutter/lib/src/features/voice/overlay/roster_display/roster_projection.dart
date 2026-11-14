import '../../../../models.dart';
import 'projection.dart';

VoiceOverlaySnapshot projectVoiceOverlayRoster({
  required VoiceOverlaySettings settings,
  required String? voiceChannelId,
  required String? rosterChannelId,
  required VoiceOverlayVoiceStatus voiceStatus,
  required Iterable<VoiceRosterMember> roster,
  required Set<String> speakingAccountIds,
  int maxParticipants = 8,
}) {
  final members = roster.map((member) {
    final speaking =
        speakingAccountIds.contains(member.accountId) &&
        !member.microphoneMuted;
    return VoiceOverlayMemberInput(
      displayName: member.displayName,
      speaking: speaking,
      microphoneMuted: member.microphoneMuted,
      deafened: member.deafened,
    );
  });
  return projectVoiceOverlay(
    settings: settings,
    voiceChannelId: voiceChannelId,
    rosterChannelId: rosterChannelId,
    voiceStatus: voiceStatus,
    members: members,
    maxParticipants: maxParticipants,
  );
}
