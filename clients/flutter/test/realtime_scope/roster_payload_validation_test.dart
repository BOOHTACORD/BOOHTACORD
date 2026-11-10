import 'package:boohtacord_desktop/src/features/realtime/lifecycle/roster_payload.dart';
import 'package:flutter_test/flutter_test.dart';

import 'roster_fixtures.dart';

void main() {
  test('unavailable uses only the fixed safe code', () {
    expect(
      validRosterPayload('voice.roster.unavailable', {
        'version': 1,
        'code': 'temporarily_unavailable',
      }),
      isTrue,
    );
    for (final payload in [
      {'version': 1, 'code': 'database timeout'},
      {'version': 1, 'code': 'temporarily_unavailable', 'detail': 'private'},
      {'version': 1, 'code': 'temporarily_unavailable', 'channels': []},
      {'version': 2, 'code': 'temporarily_unavailable'},
    ]) {
      expect(validRosterPayload('voice.roster.unavailable', payload), isFalse);
    }
  });

  test('rejects duplicates, malformed flags and overly long Unicode names', () {
    final value = snapshot();
    final channel = (value['channels'] as List).first as Map<String, dynamic>;
    final participant =
        (channel['participants'] as List).first as Map<String, dynamic>;
    final bad = [
      {
        ...value,
        'channels': [channel, channel],
      },
      {
        ...value,
        'channels': [
          {
            ...channel,
            'participants': [participant, participant],
          },
        ],
      },
      {
        ...value,
        'channels': [
          {
            ...channel,
            'participants': [
              {...participant, 'microphone_muted': 'false'},
            ],
          },
        ],
      },
      {
        ...value,
        'channels': [
          {
            ...channel,
            'participants': [
              {...participant, 'display_name': '😀' * 65},
            ],
          },
        ],
      },
    ];
    for (final payload in bad) {
      expect(validRosterPayload('voice.roster.snapshot', payload), isFalse);
    }
    expect(
      validRosterPayload('voice.roster.snapshot', {
        ...value,
        'version': 1.0,
        'revision': 1.0,
        'channels': [
          {
            ...channel,
            'participants': [
              {...participant, 'display_name': '😀' * 64},
            ],
          },
        ],
      }),
      isTrue,
    );
  });
}
