import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/features/voice/sound_events/policy.dart';
import 'package:flutter_test/flutter_test.dart';

const types = {
  'voice.member_joined': SoundEventType.joined,
  'voice.member_left': SoundEventType.left,
  'voice.stream_started': SoundEventType.started,
  'voice.stream_stopped': SoundEventType.stopped,
};
void main() {
  final cases = jsonDecode(
    File('../../contracts/voice-sound-event-policy.fixtures.json')
        .readAsStringSync(),
  ) as List<dynamic>;
  for (final item in cases) {
    final fixture = item as Map<String, dynamic>;
    test('shared fixture: ${fixture['name']}', () {
      final played = <String>[];
      final policy = VoiceSoundPolicy(
        'room',
        'self',
        (e) =>
            played.add(types.entries.firstWhere((x) => x.value == e.type).key),
      );
      policy.seed(
        (fixture['members'] as List)
            .map((x) => SoundMember(x['actor'] as String, x['lease'] as String))
            .toList(),
        (fixture['streams'] as List)
            .map(
              (x) => SoundStream(x['actor'] as String, x['session'] as String),
            )
            .toList(),
      );
      for (final dynamic value in fixture['steps'] as List) {
        final step = value as Map<String, dynamic>;
        if (step.containsKey('flush')) {
          policy.flush(step['flush'] as int);
          continue;
        }
        final time = step['time'] as int;
        policy.accept(
          SoundEvent(
            id: step['id'] as String,
            type: types[step['type']]!,
            actor: step['actor'] as String,
            session: step['session'] as String,
            channel: 'room',
            time: time,
          ),
          time,
        );
      }
      expect(played, fixture['expected']);
    });
  }
}
