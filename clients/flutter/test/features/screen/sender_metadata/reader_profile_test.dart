import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  test(
    'validated reader retains confirmed SDK limits independently of intent',
    () {
      final fixture = descriptor();
      final profile = fixture['effective_profile'] as Map<String, Object?>;
      profile['capture'] = {
        'max_width': 1280,
        'max_height': 720,
        'max_fps': 30,
      };
      final dynamic reader = parse(fixture);
      expect(reader.requestedProfileId, 'P1080_60');
      expect(reader.effectiveProfile['capture']['max_width'], 1280);
      expect(reader.effectiveProfile['capture']['max_fps'], 30);
      expect(
        reader.effectiveProfile['encoding']['layers'][0]['max_bitrate_bps'],
        8000000,
      );
    },
  );

  test('reader retains state and provenance revision without turning them into measured FPS', () {
    final fixture = descriptor()
      ..['publisher_state'] = 'updating'
      ..['viewer_state'] = 'recovering';
    final dynamic reader = parse(fixture);
    expect(reader.publisherState, 'updating');
    expect(reader.viewerState, 'recovering');
    expect(reader.profileRevision, 1);
    expect(reader.layerTopology, 'single-layer');
    expect(reader.reasonCodes, ['user-request']);
  });

  test('invalid confirmed limits still reject the complete descriptor', () {
    final fixture = descriptor();
    (fixture['effective_profile'] as Map<String, Object?>)['capture'] = {
      'max_width': 1280,
      'max_height': 720,
      'max_fps': -1,
    };
    expect(parse(fixture), isNull);
  });
}
