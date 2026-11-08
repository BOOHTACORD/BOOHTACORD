import 'package:boohtacord_desktop/src/features/voice/sound_events/policy.dart';
import 'package:flutter_test/flutter_test.dart';

SoundEvent event(
  String id,
  SoundEventType type, {
  String actor = 'other',
  String session = 'lease-1',
  int time = 10000,
  String channel = 'room',
}) => SoundEvent(
  id: id,
  type: type,
  actor: actor,
  session: session,
  time: time,
  channel: channel,
);
void main() {
  test('baseline, self, foreign and duplicates do not replay', () {
    final played = <SoundEvent>[];
    final p = VoiceSoundPolicy('room', 'self', played.add);
    p.seed([const SoundMember('existing', 'l1')], []);
    p.accept(
      event('old', SoundEventType.joined, actor: 'existing', session: 'l1'),
      10000,
    );
    p.accept(event('self', SoundEventType.joined, actor: 'self'), 10000);
    p.accept(event('foreign', SoundEventType.joined, channel: 'else'), 10000);
    p.accept(event('join', SoundEventType.joined), 10000);
    p.accept(event('join', SoundEventType.joined), 10000);
    expect(played.map((e) => e.type), [SoundEventType.joined]);
  });
  test('same lease flap is quiet and leaving suppresses stream stop', () {
    final played = <SoundEvent>[];
    final p = VoiceSoundPolicy('room', 'self', played.add);
    p.seed(
      [const SoundMember('other', 'lease-1')],
      [const SoundStream('other', 'stream-1')],
    );
    p.accept(event('l1', SoundEventType.left), 10000);
    p.accept(event('j1', SoundEventType.joined, time: 10500), 10500);
    p.flush(12000);
    expect(played, isEmpty);
    p.accept(
      event('s1', SoundEventType.stopped, session: 'stream-1', time: 13000),
      13000,
    );
    p.accept(event('l2', SoundEventType.left, time: 13100), 13100);
    p.flush(15000);
    expect(played.map((e) => e.type), [SoundEventType.left]);
  });
  test('old events are dropped and burst limit survives reconnect', () {
    final played = <SoundEvent>[];
    final p = VoiceSoundPolicy('room', 'self', played.add);
    p.seed([const SoundMember('old', 'lease-old')], []);
    p.accept(
      event('old', SoundEventType.left, actor: 'old', session: 'lease-old'),
      10000,
    );
    p.flush(20000);
    expect(played, isEmpty);
    for (var i = 0; i < 3; i++) {
      p.accept(
        event(
          'j$i',
          SoundEventType.joined,
          actor: 'u$i',
          session: 'l$i',
          time: 21000,
        ),
        21000,
      );
    }
    p.pause();
    p.seed([], []);
    p.accept(
      event('j4', SoundEventType.joined, actor: 'u4', time: 21500),
      21500,
    );
    expect(played.length, 3);
  });
  test('replacement session does not duplicate stream start', () {
    final played = <SoundEvent>[];
    final p = VoiceSoundPolicy('room', 'self', played.add);
    p.seed([const SoundMember('other', 'lease-1')], []);
    p.accept(
      event('start', SoundEventType.started, session: 'stream-1'),
      10000,
    );
    p.accept(
      event('temp', SoundEventType.stopped, session: 'stream-1', time: 10500),
      10500,
    );
    p.accept(
      event(
        'replacement',
        SoundEventType.started,
        session: 'stream-1',
        time: 11000,
      ),
      11000,
    );
    p.flush(12500);
    p.accept(
      event('final', SoundEventType.stopped, session: 'stream-1', time: 13000),
      13000,
    );
    p.flush(14500);
    expect(played.map((e) => e.type), [
      SoundEventType.started,
      SoundEventType.stopped,
    ]);
  });
}
