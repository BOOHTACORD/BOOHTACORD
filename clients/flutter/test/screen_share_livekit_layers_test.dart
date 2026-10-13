import 'package:boohtacord_desktop/src/features/screen/metrics/livekit_layers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

void main() {
  test(
    'encoder reports are bounded labels and flags, never hardware inference',
    () {
      final known = screenSenderSourcesFromReports([
        rtc.StatsReport('out', 'outbound-rtp', 1000000, {
          'kind': 'video',
          'framesEncoded': 10,
          'encoderImplementation': 'libvpx',
          'powerEfficientEncoder': false,
          'qpSum': 320,
        }),
      ]).single.counters;
      expect(known.encoderImplementation, 'libvpx');
      expect(known.powerEfficientEncoder, false);
      expect(known.qpSum, 320);
      final unavailable = screenSenderSourcesFromReports([
        rtc.StatsReport('out', 'outbound-rtp', 1000000, {
          'kind': 'video',
          'encoderImplementation': 'private-identity@192.0.2.9',
          'powerEfficientEncoder': 'true',
          'qpSum': double.nan,
        }),
      ]).single.counters;
      expect(unavailable.encoderImplementation, isNull);
      expect(unavailable.powerEfficientEncoder, isNull);
      expect(unavailable.qpSum, isNull);
    },
  );

  test('keeps actual sent and encoded counters separate', () {
    final sample = screenSenderSourcesFromReports([
      rtc.StatsReport('out', 'outbound-rtp', 1000000, {
        'kind': 'video',
        'framesEncoded': 60,
        'framesSent': 45,
      }),
    ]).single.counters;
    expect(sample.encodedFrames, 60);
    expect(sample.framesSent, 45);
    expect(sample.frameCounterSource, 'encoded');
  });

  test(
    'does not pair remote rows with different outbound identity or SSRC',
    () {
      final rows = [
        rtc.StatsReport('out', 'outbound-rtp', 1000000, {
          'kind': 'video',
          'ssrc': 1,
          'remoteId': 'remote',
          'framesEncoded': 10,
        }),
        rtc.StatsReport('audio', 'outbound-rtp', 1000000, {
          'kind': 'audio',
          'packetsSent': 50,
        }),
        rtc.StatsReport('remote', 'remote-inbound-rtp', 1000000, {
          'localId': 'other',
          'ssrc': 2,
          'packetsLost': 10,
          'roundTripTime': .5,
        }),
      ];
      final samples = screenSenderSourcesFromReports(rows);
      expect(samples, hasLength(1));
      expect(samples.single.counters.packetsLost, isNull);
      expect(samples.single.roundTripTimeSeconds, isNull);
      expect(samples.single.counters.framesSent, isNull);
      expect(samples.single.counters.encodedFrames, 10);
      expect(samples.single.counters.frameCounterSource, 'encoded');
    },
  );

  test('keeps SSRC and pairs remote loss and RTT to the matching outbound', () {
    final reports = [
      rtc.StatsReport('codec', 'codec', 1000, {'mimeType': 'video/VP8'}),
      rtc.StatsReport('outbound-a', 'outbound-rtp', 1000, {
        'codecId': 'codec',
        'ssrc': 101,
        'rid': 'q',
        'remoteId': 'remote-a',
        'packetsSent': 40,
        'framesSent': 20,
      }),
      rtc.StatsReport('outbound-b', 'outbound-rtp', 1000, {
        'codecId': 'codec',
        'ssrc': 202,
        'rid': 'f',
        'remoteId': 'remote-b',
        'packetsSent': 80,
        'framesSent': 40,
      }),
      rtc.StatsReport('remote-a', 'remote-inbound-rtp', 1000, {
        'packetsLost': 3,
        'roundTripTime': 0.04,
      }),
      rtc.StatsReport('remote-b', 'remote-inbound-rtp', 1000, {
        'packetsLost': 7,
        'roundTripTime': 0.08,
      }),
    ];

    final sources = screenSenderSourcesFromReports(reports);

    expect(sources.map((source) => source.counters.ssrc), [101, 202]);
    expect(sources.map((source) => source.counters.packetsLost), [3, 7]);
    expect(sources.map((source) => source.roundTripTimeSeconds), [0.04, 0.08]);
    expect(sources.map((source) => source.counters.encodedFrames), [
      null,
      null,
    ]);
    expect(sources.map((source) => source.counters.frameCounterSource), [
      'sent',
      'sent',
    ]);
    expect(sources.map((source) => source.counters.codec), [
      'video/VP8',
      'video/VP8',
    ]);
  });
}
