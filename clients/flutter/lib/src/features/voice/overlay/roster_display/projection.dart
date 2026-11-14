enum VoiceOverlayVoiceStatus { disconnected, connected, reconnecting }

class VoiceOverlaySettings {
  const VoiceOverlaySettings({
    required this.enabled,
    required this.onlySpeakers,
    this.maxParticipants = 8,
  });

  final bool enabled;
  final bool onlySpeakers;
  final int maxParticipants;
}

class VoiceOverlayMemberInput {
  const VoiceOverlayMemberInput({
    required this.displayName,
    required this.speaking,
    required this.microphoneMuted,
    this.deafened = false,
  });

  final String displayName;
  final bool speaking;
  final bool microphoneMuted;
  final bool deafened;
}

class VoiceOverlayMember {
  const VoiceOverlayMember({
    required this.displayName,
    required this.speaking,
    required this.microphoneMuted,
    this.deafened = false,
  });

  final String displayName;
  final bool speaking;
  final bool microphoneMuted;
  final bool deafened;
}

class VoiceOverlaySnapshot {
  const VoiceOverlaySnapshot({required this.visible, required this.members});

  final bool visible;
  final List<VoiceOverlayMember> members;
}

VoiceOverlaySnapshot projectVoiceOverlay({
  required VoiceOverlaySettings settings,
  required String? voiceChannelId,
  required String? rosterChannelId,
  required VoiceOverlayVoiceStatus voiceStatus,
  required Iterable<VoiceOverlayMemberInput> members,
  int maxParticipants = 8,
}) {
  final channelMatches =
      voiceChannelId != null &&
      voiceChannelId.isNotEmpty &&
      voiceChannelId == rosterChannelId;
  if (!settings.enabled ||
      !channelMatches ||
      voiceStatus == VoiceOverlayVoiceStatus.disconnected) {
    return const VoiceOverlaySnapshot(visible: false, members: []);
  }

  final cap = maxParticipants.clamp(1, 12).toInt();
  final projected = <VoiceOverlayMember>[];
  for (final member in members) {
    final name = member.displayName.trim();
    final speaking =
        voiceStatus == VoiceOverlayVoiceStatus.connected &&
        member.speaking &&
        !member.deafened;
    if (settings.onlySpeakers && !speaking) continue;
    projected.add(
      VoiceOverlayMember(
        displayName: name.isEmpty ? 'Участник' : name,
        speaking: speaking,
        microphoneMuted: member.microphoneMuted,
        deafened: member.deafened,
      ),
    );
    if (projected.length >= cap) break;
  }
  return VoiceOverlaySnapshot(
    visible: true,
    members: List.unmodifiable(projected),
  );
}
