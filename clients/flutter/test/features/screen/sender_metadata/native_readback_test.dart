import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/native_readback.dart';

void main() {
  test(
    'FMTP fallback joins fresh parameter payload to the used codec report',
    () {
      final reports = [
        rtc.StatsReport('used', 'codec', 1, {
          'mimeType': 'video/H264',
          'payloadType': 102,
        }),
        rtc.StatsReport('out', 'outbound-rtp', 1, {
          'kind': 'video',
          'codecId': 'used',
        }),
      ];
      final codecs = [
        rtc.RTCRTPCodec(
          name: 'H264',
          kind: 'video',
          payloadType: 100,
          parameters: {'profile-level-id': '42e01f'},
        ),
        rtc.RTCRTPCodec(
          name: 'H264',
          kind: 'video',
          payloadType: 102,
          parameters: {'packetization-mode': '1', 'profile-level-id': '42e033'},
        ),
      ];
      expect(
        usedScreenCodecFmtp(reports, codecs),
        'packetization-mode=1;profile-level-id=42e033',
      );
      expect(usedScreenCodecFmtp(reports, [codecs.first]), isNull);
    },
  );
  test(
    'codec follows used outbound codecId rather than advertised preference',
    () {
      final reports = [
        rtc.StatsReport('unused', 'codec', 1, {'mimeType': 'video/VP8'}),
        rtc.StatsReport('used', 'codec', 1, {
          'mimeType': 'video/H264',
          'sdpFmtpLine': 'packetization-mode=1;profile-level-id=42e033',
        }),
        rtc.StatsReport('out', 'outbound-rtp', 1, {
          'kind': 'video',
          'codecId': 'used',
        }),
      ];
      expect(usedScreenCodec(reports), (
        'H264',
        'packetization-mode=1;profile-level-id=42e033',
      ));
    },
  );
  test('missing or ambiguous negotiated codec remains unknown', () {
    expect(usedScreenCodec([]), isNull);
    expect(
      usedScreenCodec([
        rtc.StatsReport('c', 'codec', 1, {'mimeType': 'video/VP8'}),
        rtc.StatsReport('out', 'outbound-rtp', 1, {
          'kind': 'audio',
          'codecId': 'c',
        }),
      ]),
      isNull,
    );
  });
}
