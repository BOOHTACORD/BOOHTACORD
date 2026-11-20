import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listener playback uses a separate nonsticky mediaPlayback service', () {
    const root = 'packages/boohtacord_voice_foreground/android/src/main';
    final manifest = File('$root/AndroidManifest.xml').readAsStringSync();
    final service = File(
      '$root/kotlin/ru/boohtacord/voice/start/VoicePlaybackService.kt',
    ).readAsStringSync();
    final plugin = File(
      '$root/kotlin/ru/boohtacord/voice/start/VoicePlaybackPlugin.kt',
    ).readAsStringSync();

    expect(manifest, contains('FOREGROUND_SERVICE_MEDIA_PLAYBACK'));
    expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
    expect(manifest, contains('android:exported="false"'));
    expect(service, contains('FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK'));
    expect(service, isNot(contains('FOREGROUND_SERVICE_TYPE_MICROPHONE')));
    expect(service, contains('START_NOT_STICKY'));
    expect(service, isNot(contains('RECORD_AUDIO')));
    expect(service, isNot(contains('AudioRecord')));
    expect(service, isNot(contains('MediaProjection')));
    expect(plugin, contains('VoicePlaybackAdmissionPolicy.permitsStart'));
    expect(plugin, contains('visibility.visible'));
  });
}
