import 'package:livekit_client/livekit_client.dart';

import '../sound_playback/runtime.dart';
import 'livekit.dart';
import 'types.dart';

RoomSoundObserver bindRoomSounds(
  Room room,
  EventsListener<RoomEvent> listener,
  VoiceSoundRuntime runtime,
  bool Function() owns,
) {
  final observer = RoomSoundObserver(room, runtime, owns);
  listener.on<ParticipantConnectedEvent>(
    (e) => observer.accept(
      e.participant,
      SoundEventType.joined,
      e.participant.identity,
    ),
  );
  listener.on<ParticipantDisconnectedEvent>(
    (e) => observer.accept(
      e.participant,
      SoundEventType.left,
      e.participant.identity,
    ),
  );
  listener.on<TrackPublishedEvent>((e) {
    if (e.publication.source == TrackSource.screenShareVideo) {
      observer.accept(e.participant, SoundEventType.started, e.publication.sid);
    }
  });
  listener.on<TrackUnpublishedEvent>((e) {
    if (e.publication.source == TrackSource.screenShareVideo) {
      observer.accept(e.participant, SoundEventType.stopped, e.publication.sid);
    }
  });
  listener.on<RoomReconnectingEvent>((_) => observer.pause());
  listener.on<RoomResumingEvent>((_) => observer.pause());
  listener.on<RoomReconnectedEvent>((_) => observer.seed());
  listener.on<RoomDisconnectedEvent>((_) => observer.pause());
  return observer;
}
