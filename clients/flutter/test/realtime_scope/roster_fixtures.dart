const id = '11111111-1111-4111-8111-111111111111';
const time = '2026-11-09T00:00:00Z';
Map<String, dynamic> snapshot() => {
  'version': 1,
  'generation': id,
  'revision': 1,
  'observed_at': time,
  'channels': [
    {
      'channel_id': id,
      'participants': [
        {
          'account_id': id,
          'display_name': 'Участник',
          'screen_sharing': false,
          'microphone_muted': true,
        },
      ],
    },
  ],
};
