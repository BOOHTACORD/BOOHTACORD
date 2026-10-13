import 'package:boohtacord_desktop/src/features/screen/metrics/layers.dart';
import 'package:flutter_test/flutter_test.dart';

ScreenSenderLayerCounters layer({
  String id = 'stream-full',
  String rid = 'f',
  int width = 1920,
  double timestamp = 1000,
  double? frames = 0,
  double? encoded,
  double? qpSum,
  double bytes = 0,
  double packets = 0,
  double lost = 0,
  double nacks = 0,
  int? ssrc = 1,
}) => ScreenSenderLayerCounters(
  streamId: id,
  ssrc: ssrc,
  rid: rid,
  codec: 'video/VP8',
  timestampMs: timestamp,
  width: width,
  height: width * 9 / 16,
  framesSent: frames,
  encodedFrames: encoded,
  qpSum: qpSum,
  bytesSent: bytes,
  packetsSent: packets,
  packetsLost: lost,
  retransmittedPackets: 0,
  nackCount: nacks,
  pliCount: 0,
  firCount: 0,
);

void main() {
  test(
    'average QP uses encoded delta and unavailable/reset QP stays unknown',
    () {
      final sampler = ScreenSenderLayerSampler();
      sampler.sample([layer(frames: 100, encoded: 200, qpSum: 1000)], 1000);
      final next = sampler
          .sample([
            layer(timestamp: 2000, frames: 130, encoded: 230, qpSum: 1960),
          ], 2000)
          .layers
          .single;
      expect(next.averageQp, 32);
      final reset = sampler
          .sample([
            layer(timestamp: 3000, frames: 160, encoded: 260, qpSum: 10),
          ], 3000)
          .layers
          .single;
      expect(reset.averageQp, isNull);
      expect(reset.framesPerSecond, 30);
      final missing = sampler
          .sample([layer(timestamp: 4000, frames: 190, encoded: 290)], 4000)
          .layers
          .single;
      expect(missing.averageQp, isNull);
    },
  );

  test(
    'rate window uses actual monotonic receive gap not RTC wall timestamp',
    () {
      final sampler = ScreenSenderLayerSampler();
      sampler.sample([layer(timestamp: 1000, frames: 100, encoded: 150)], 2000);
      final next = sampler
          .sample([layer(timestamp: 3000, frames: 145, encoded: 210)], 3000)
          .layers
          .single;
      expect(next.windowMs, 1000);
      expect(next.encodedFramesPerSecond, 60);
      expect(next.sentFramesPerSecond, 45);
      expect(next.framesPerSecond, 60);
      expect(next.timestampMs, 3000);
    },
  );

  test('uncertain source timestamp or monotonic clock never yields rates', () {
    for (final timestamp in [999.0, double.nan, -1.0]) {
      final sampler = ScreenSenderLayerSampler();
      sampler.sample([layer(timestamp: 1000, frames: 100, encoded: 150)], 1000);
      final next = sampler
          .sample([
            layer(timestamp: timestamp, frames: 145, encoded: 210),
          ], 2000)
          .layers
          .single;
      expect(next.encodedFramesPerSecond, isNull);
      expect(next.sentFramesPerSecond, isNull);
    }
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([layer(frames: 100, encoded: 150)], 1000);
    final backwards = sampler
        .sample([layer(timestamp: 2000, frames: 145, encoded: 210)], 999)
        .layers
        .single;
    expect(backwards.framesPerSecond, isNull);
  });

  test('reports encoded and sent FPS independently using encoded primary', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([layer(frames: 100, encoded: 150)], 1000);
    final next = sampler
        .sample([layer(timestamp: 2000, frames: 145, encoded: 210)], 2000)
        .layers
        .single;
    expect(next.encodedFramesPerSecond, 60);
    expect(next.sentFramesPerSecond, 45);
    expect(next.framesPerSecond, 60);
    expect(next.frameCounterSource, 'encoded');
  });

  test(
    'independent counters retain measured zero or transport-only progress',
    () {
      final sampler = ScreenSenderLayerSampler();
      sampler.sample([layer(frames: 100, encoded: 150)], 1000);
      final next = sampler
          .sample([layer(timestamp: 2000, frames: 130, encoded: 150)], 2000)
          .layers
          .single;
      expect(next.state, 'INACTIVE');
      expect(next.framesPerSecond, isNull);
      expect(next.encodedFramesPerSecond, 0);
      expect(next.sentFramesPerSecond, 30);
    },
  );

  test('missing sent counter remains unknown while encoded progresses', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([layer(frames: null, encoded: 100)], 1000);
    final next = sampler
        .sample([layer(timestamp: 2000, frames: null, encoded: 130)], 2000)
        .layers
        .single;
    expect(next.state, 'ACTIVE');
    expect(next.sentFramesPerSecond, isNull);
    expect(next.encodedFramesPerSecond, 30);
    expect(next.framesPerSecond, 30);
  });

  test(
    'encoded reset and frozen timestamp invalidate separate frame rates',
    () {
      final sampler = ScreenSenderLayerSampler();
      sampler.sample([layer(frames: 100, encoded: 200)], 1000);
      final reset = sampler
          .sample([layer(timestamp: 2000, frames: 130, encoded: 1)], 2000)
          .layers
          .single;
      expect(reset.state, 'UNKNOWN');
      expect(reset.encodedFramesPerSecond, isNull);
      expect(reset.sentFramesPerSecond, isNull);
      final frozen = sampler
          .sample([layer(timestamp: 2000, frames: 160, encoded: 31)], 3000)
          .layers
          .single;
      expect(frozen.encodedFramesPerSecond, isNull);
      expect(frozen.sentFramesPerSecond, isNull);
    },
  );

  test(
    'keeps per RID rates separate and selects the higher progressing layer',
    () {
      final sampler = ScreenSenderLayerSampler();
      sampler.sample([
        layer(),
        layer(id: 'stream-low', rid: 'q', width: 640),
      ], 1000);
      final result = sampler.sample([
        layer(
          timestamp: 2000,
          frames: 30,
          bytes: 100000,
          packets: 100,
          lost: 2,
          nacks: 2,
        ),
        layer(
          id: 'stream-low',
          rid: 'q',
          width: 640,
          timestamp: 2000,
          frames: 15,
          bytes: 50000,
          packets: 50,
          lost: 1,
        ),
      ], 2000);
      expect(result.selected?.rid, 'f');
      expect(result.selected?.framesPerSecond, 30);
      expect(result.selected?.nackPerSecond, 2);
      expect(result.layers.map((item) => item.framesPerSecond), [30, 15]);
    },
  );

  test('keeps first, reset and stale samples unavailable and rejects negative loss', () {
    final sampler = ScreenSenderLayerSampler();
    final first = sampler.sample([layer()], 1000);
    expect(first.selected, isNull);
    sampler.sample([layer(timestamp: 2000, frames: 30, bytes: 1000)], 2000);
    final reset = sampler.sample([
      layer(timestamp: 3000, frames: 1, bytes: 1),
    ], 3000);
    expect(reset.selected, isNull);
    final stale = sampler.sample([
      layer(timestamp: 4000, frames: 31, bytes: 2000, packets: 10, lost: -1),
    ], 20000);
    expect(stale.layers.single.state, 'STALE');
    expect(stale.layers.single.packetLossPercent, isNull);
  });

  test('starts a new counter window when SSRC changes', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([layer(frames: 10, bytes: 100)], 1000);
    final changed = sampler.sample([
      layer(timestamp: 2000, frames: 40, bytes: 1100, ssrc: 2),
    ], 2000);
    expect(changed.selected, isNull);
    final next = sampler.sample([
      layer(timestamp: 3000, frames: 70, bytes: 2100, ssrc: 2),
    ], 3000);
    expect(next.selected?.framesPerSecond, 30);
  });

  test(
    'does not select a frozen high layer because bytes continue to grow',
    () {
      final sampler = ScreenSenderLayerSampler();
      sampler.sample([
        layer(frames: 10, bytes: 100),
        layer(id: 'low', rid: 'q', width: 640, frames: 10, bytes: 100),
      ], 1000);
      final result = sampler.sample([
        layer(timestamp: 2000, frames: 10, bytes: 1100),
        layer(
          id: 'low',
          rid: 'q',
          width: 640,
          timestamp: 2000,
          frames: 40,
          bytes: 1100,
        ),
      ], 2000);
      expect(result.layers.first.state, 'INACTIVE');
      expect(result.selected?.rid, 'q');
    },
  );

  test('signed loss correction does not reset frame and byte progress', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([layer(lost: 4)], 1000);
    final next = sampler.sample([
      layer(timestamp: 2000, frames: 30, bytes: 1000, packets: 10, lost: 2),
    ], 2000);
    expect(next.selected?.framesPerSecond, 30);
    expect(next.selected?.packetLossPercent, isNull);
  });

  test('invalidates all rates for an interval with a counter reset', () {
    final sampler = ScreenSenderLayerSampler();
    sampler.sample([layer(frames: 10, bytes: 1000, packets: 20)], 1000);
    final reset = sampler.sample([
      layer(timestamp: 2000, frames: 40, bytes: 2000, packets: 2),
    ], 2000);
    expect(reset.layers.single.state, 'UNKNOWN');
    expect(reset.layers.single.framesPerSecond, isNull);
    expect(reset.layers.single.bitrateBps, isNull);
  });
}
