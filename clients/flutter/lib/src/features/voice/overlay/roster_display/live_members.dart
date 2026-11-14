import 'package:livekit_client/livekit_client.dart';

import '../../../../models.dart';

List<VoiceRosterMember> liveOverlayMembers(
  Room room,
  VoiceRoomRoster? roster,
  String? self,
  bool microphoneMuted, {
  bool deafened = false,
}) {
  final cached = {
    for (final member in roster?.participants ?? const <VoiceRosterMember>[])
      member.accountId: member,
  };
  final members = <VoiceRosterMember>[];
  if (self != null && room.localParticipant != null) {
    members.add(
      VoiceRosterMember(
        accountId: self,
        displayName: cached[self]?.displayName ?? room.localParticipant!.name,
        screenSharing: room.localParticipant!.isScreenShareEnabled(),
        microphoneMuted: microphoneMuted,
        deafened: deafened,
      ),
    );
  }
  for (final peer in room.remoteParticipants.values) {
    final metadata = peer.metadata;
    if (metadata == null || !metadata.startsWith('account:')) continue;
    final account = metadata.substring('account:'.length);
    if (account.isEmpty || account == self) continue;
    members.add(
      VoiceRosterMember(
        accountId: account,
        displayName: cached[account]?.displayName ?? peer.name,
        screenSharing: peer.isScreenShareEnabled(),
        microphoneMuted: !peer.isMicrophoneEnabled(),
        deafened: cached[account]?.deafened ?? false,
      ),
    );
  }
  return members;
}
