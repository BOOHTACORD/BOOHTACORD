import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/services/voice_audio_session_bootstrap.dart';

void main() {
  test('Android voice startup preserves audio focus of other music apps', () {
    final config = androidVoiceAudioConfiguration.toMap();

    expect(config['manageAudioFocus'], isFalse);
    expect(config['androidAudioMode'], 'inCommunication');
    expect(config['androidAudioFocusMode'], 'gain');
    expect(config['androidAudioStreamType'], 'voiceCall');
    expect(config['androidAudioAttributesUsageType'], 'voiceCommunication');
    expect(config['androidAudioAttributesContentType'], 'speech');
  });
}
