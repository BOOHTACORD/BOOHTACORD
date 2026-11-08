import 'package:boohtacord_desktop/src/features/voice/sound_events/policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'due stream stop is suppressed when leave arrives in the same batch',
    () {
      final played = <SoundEvent>[];
      final p = VoiceSoundPolicy('room', 'self', played.add);
      p.seed(
        [const SoundMember('other', 'lease-1')],
        [const SoundStream('other', 'stream-1')],
      );
      p.accept(
        const SoundEvent(
          id: 'stop',
          type: SoundEventType.stopped,
          actor: 'other',
          session: 'stream-1',
          channel: 'room',
          time: 10000,
        ),
        10000,
      );
      p.accept(
        const SoundEvent(
          id: 'leave',
          type: SoundEventType.left,
          actor: 'other',
          session: 'lease-1',
          channel: 'room',
          time: 11200,
        ),
        11200,
      );
      p.flush(13000);
      expect(played.map((e) => e.type), [SoundEventType.left]);
    },
  );
}
