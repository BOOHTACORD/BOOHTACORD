import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/confirmed_profile.dart';

Map<String, Object?> capture() => {
  'schema_version': 1,
  'status': 'active',
  'config_confirmed': true,
  'configured_width': 1920,
  'configured_height': 1080,
  'configured_max_fps': 30,
  'actual_width': 1600,
  'actual_height': 900,
};
rtc.RTCRtpEncoding encoding() => rtc.RTCRtpEncoding(
  maxFramerate: 30,
  maxBitrate: 5000000,
  scaleResolutionDownBy: 2,
);

void main() {
  test('confirmed capture plus fresh encoding derives applied limits only', () {
    final value = confirmedScreenProfile(capture(), [encoding()]);
    expect(value, {
      'capture': {'max_width': 1920, 'max_height': 1080, 'max_fps': 30},
      'encoding': {
        'codec': null,
        'layers': [
          {
            'rid': null,
            'width': 800,
            'height': 450,
            'max_fps': 30,
            'max_bitrate_bps': 5000000,
            'scale_down_by': 2.0,
            'active': true,
          },
        ],
      },
    });
  });
  test('pending capture cannot substitute selected quality for actual', () {
    for (final change in [
      {'config_confirmed': false},
      {'status': 'stopped'},
      {'configured_max_fps': null},
      {'actual_width': null},
    ]) {
      expect(
        confirmedScreenProfile({...capture(), ...change}, [encoding()]),
        isNull,
      );
    }
  });
  test('missing native encoding limit stays pending instead of defaults', () {
    for (final value in [
      rtc.RTCRtpEncoding(maxBitrate: 5000000),
      rtc.RTCRtpEncoding(maxFramerate: 30),
      rtc.RTCRtpEncoding(
        maxFramerate: 30,
        maxBitrate: 5000000,
        scaleResolutionDownBy: null,
      ),
    ]) {
      expect(confirmedScreenProfile(capture(), [value]), isNull);
    }
    expect(confirmedScreenProfile(capture(), []), isNull);
  });
  test('negotiated codec is optional observed data, never requested codec', () {
    expect(
      (confirmedScreenProfile(capture(), [
            encoding(),
          ], negotiatedCodec: 'VP8')!['encoding']
          as Map)['codec'],
      'VP8',
    );
  });
}
