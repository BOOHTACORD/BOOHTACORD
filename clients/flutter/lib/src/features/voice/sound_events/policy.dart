import 'limit.dart';
import 'pending.dart';
import 'types.dart';
export 'types.dart';
class VoiceSoundPolicy {
  VoiceSoundPolicy(this.channel, this.self, this.play);
  final String channel, self;
  final void Function(SoundEvent) play;
  final _members = <String, String>{};
  final _streams = <String, Set<String>>{};
  final _leaves = <String, PendingSoundEvent>{};
  final _stops = <String, PendingSoundEvent>{};
  final _seen = <String>{};
  final _limit = SoundBurstLimit();
  bool _active = false;
  void seed(List<SoundMember> members, List<SoundStream> streams) {
    pause();
    for (final m in members) {
      _members[m.actor] = m.lease;
    }
    for (final s in streams) {
      _streamSet(s.actor).add(s.session);
    }
    _active = true;
  }
  void pause() {
    _active = false;
    _members.clear();
    _streams.clear();
    _leaves.clear();
    _stops.clear();
    _seen.clear();
  }
  void accept(SoundEvent e, int now) {
    if (!_active ||
        e.channel != channel ||
        e.actor.isEmpty ||
        e.actor == self ||
        e.actor.startsWith('voice-lease:') ||
        e.session.isEmpty ||
        e.id.isEmpty ||
        e.time < now - 5000 ||
        e.time > now + 1000) {
      return;
    }
    final key = '${e.id}\u0000${e.actor}\u0000${e.session}';
    if (!_seen.add(key)) return;
    if (_seen.length > 256) _seen.remove(_seen.first);
    if (e.type != SoundEventType.left) flush(now);
    switch (e.type) {
      case SoundEventType.joined:
        _join(e, now);
      case SoundEventType.left:
        if (_members[e.actor] == e.session) {
          _leaves[e.actor] = PendingSoundEvent(e, now + 1200);
        }
        flush(now);
      case SoundEventType.started:
        _start(e, now);
      case SoundEventType.stopped:
        if (_streams[e.actor]?.contains(e.session) == true) {
          _stops['${e.actor}\u0000${e.session}'] = PendingSoundEvent(e, now + 1200);
        }
    }
  }

  void flush(int now) {
    if (!_active) return;
    for (final entry in _leaves.entries.toList()) {
      if (entry.value.due <= now) {
        _finishLeave(entry.key, entry.value.event, now);
      }
    }
    for (final entry in _stops.entries.toList()) {
      if (entry.value.due > now) continue;
      _stops.remove(entry.key);
      final e = entry.value.event;
      if (!_leaves.containsKey(e.actor) && _members.containsKey(e.actor)) {
        _streams[e.actor]?.remove(e.session);
        _emit(e, now);
      }
    }
  }

  void _join(SoundEvent e, int now) {
    final pending = _leaves[e.actor];
    if (pending != null && pending.event.session == e.session) {
      _leaves.remove(e.actor);
      return;
    }
    if (pending != null) _finishLeave(e.actor, pending.event, now);
    if (_members[e.actor] == e.session) return;
    _members[e.actor] = e.session;
    _emit(e, now);
  }

  void _start(SoundEvent e, int now) {
    if (!_members.containsKey(e.actor) || _leaves.containsKey(e.actor)) return;
    final key = '${e.actor}\u0000${e.session}';
    if (_stops.remove(key) != null) return;
    if (!_streamSet(e.actor).add(e.session)) return;
    _emit(e, now);
  }

  void _finishLeave(String actor, SoundEvent e, int now) {
    _leaves.remove(actor);
    _members.remove(actor);
    _streams.remove(actor);
    _stops.removeWhere((_, v) => v.event.actor == actor);
    _emit(e, now);
  }

  Set<String> _streamSet(String actor) =>
      _streams.putIfAbsent(actor, () => <String>{});
  void _emit(SoundEvent e, int now) {
    if (e.time >= now - 5000 && _limit.allow(now)) play(e);
  }
}
