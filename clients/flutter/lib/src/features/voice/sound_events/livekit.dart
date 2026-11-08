import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../sound_playback/runtime.dart';
import 'policy.dart';

class RoomSoundObserver {
  RoomSoundObserver(this.room, this.runtime, this.owns);
  final Room room;
  final VoiceSoundRuntime runtime;
  final bool Function() owns;
  VoiceSoundPolicy? _policy;
  Timer? _timer;
  int _sequence = 0;
  final _custom = <String, String>{};
  String? actor(Participant participant) {
    final metadata = participant.metadata;
    return metadata != null &&
            RegExp(r'^account:[0-9a-fA-F-]{36}$').hasMatch(metadata)
        ? metadata.substring(8).toLowerCase()
        : null;
  }

  void seed() {
    pause();
    if (!owns()) return;
    _policy = VoiceSoundPolicy(
      room.name ?? '',
      room.localParticipant == null ? '' : actor(room.localParticipant!) ?? '',
      (event) {
        runtime.submit(
          event.type.name,
          custom: event.type == SoundEventType.joined
              ? _custom[event.actor]
              : null,
        );
      },
    );
    final peers = room.remoteParticipants.values.where((p) => actor(p) != null);
    _policy!.seed(
      peers.map((p) => SoundMember(actor(p)!, p.identity)).toList(),
      peers
          .expand(
            (p) => p.videoTrackPublications
                .where((t) => t.source == TrackSource.screenShareVideo)
                .map((t) => SoundStream(actor(p)!, t.sid)),
          )
          .toList(),
    );
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (owns()) {
        _policy?.flush(DateTime.now().millisecondsSinceEpoch);
      } else {
        pause();
      }
    });
  }

  void accept(Participant participant, SoundEventType type, String session) {
    final account = actor(participant);
    if (!owns() || account == null) return;
    final id = participant.attributes['boohtacord.join_sound_id'];
    if (id != null) {
      _custom[account] = id;
    } else {
      _custom.remove(account);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    _policy?.accept(
      SoundEvent(
        id: '${++_sequence}',
        type: type,
        actor: account,
        session: session,
        channel: room.name ?? '',
        time: now,
      ),
      now,
    );
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    _policy?.pause();
    _policy = null;
    _custom.clear();
    runtime.silence();
  }
}
