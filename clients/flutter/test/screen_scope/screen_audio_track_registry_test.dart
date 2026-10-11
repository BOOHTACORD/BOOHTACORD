import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/audio_track_registry.dart';

import 'fakes.dart';

void main() {
  test(
    'stops the audio track associated with a discarded video track',
    () async {
      final registry = ScreenAudioTrackRegistry();
      final video = FakeScreenTrack();
      final audio = FakeScreenAudioTrack();
      registry.register(video, audio);

      final ownedAudio = registry.take(video);
      if (ownedAudio != null) await registry.stop(ownedAudio);

      expect(audio.stopCalls, 1);
      expect(registry[video], isNull);
    },
  );

  test('stops every remaining audio track and clears the registry', () async {
    final registry = ScreenAudioTrackRegistry();
    final firstVideo = FakeScreenTrack();
    final secondVideo = FakeScreenTrack();
    final firstAudio = FakeScreenAudioTrack();
    final secondAudio = FakeScreenAudioTrack();
    registry.register(firstVideo, firstAudio);
    registry.register(secondVideo, secondAudio);

    await registry.stopAll();
    await registry.stopAll();

    expect(firstAudio.stopCalls, 1);
    expect(secondAudio.stopCalls, 1);
    expect(registry[firstVideo], isNull);
    expect(registry[secondVideo], isNull);
  });
}
