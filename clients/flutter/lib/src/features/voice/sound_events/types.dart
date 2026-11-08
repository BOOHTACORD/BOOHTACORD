enum SoundEventType { joined, left, started, stopped }

class SoundEvent {
  const SoundEvent({
    required this.id,
    required this.type,
    required this.actor,
    required this.session,
    required this.channel,
    required this.time,
  });
  final String id, actor, session, channel;
  final SoundEventType type;
  final int time;
}

class SoundMember {
  const SoundMember(this.actor, this.lease);
  final String actor, lease;
}

class SoundStream {
  const SoundStream(this.actor, this.session);
  final String actor, session;
}
