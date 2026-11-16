import 'dart:async';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/metrics/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/metrics/telemetry_envelope.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('sender sampling keeps updating while HTTP export is stalled', () async {
    final response = Completer<http.Response>();
    var posts = 0;
    var observations = 0;
    final sender = _StatsSender();
    final api = ApiClient(
      client: MockClient((_) {
        posts++;
        return response.future;
      }),
    );
    const leaseId = '11111111-1111-4111-8111-111111111111';
    expect(api.transport.session.telemetry.bindMediaLease(leaseId), isTrue);
    final track = _ScreenTrack(sender);
    final metrics = ScreenShareMetricsController(
      api,
      SessionScope(),
      readRoom: () => null,
      isSharing: () => true,
      readQuality: () => ScreenShareQuality.balanced,
      changed: () {},
      readTelemetryScope: () => const ScreenTelemetryPublicationScope(
        ownerLeaseId: leaseId,
        mediaSessionId: 'media-session-1',
        publicationGeneration: 3,
      ),
      captureObservation: () => (observation) async {
        observations++;
      },
    );

    metrics.start(track);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final firstSampleAt = metrics.sampledAt;
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    expect(
      posts,
      2,
      reason: 'one admin export and one ephemeral relay may be active',
    );
    expect(
      sender.requests,
      greaterThanOrEqualTo(2),
      reason: 'the relay must reuse the existing getStats polling loop',
    );
    expect(sender.requests, greaterThanOrEqualTo(2));
    expect(observations, greaterThanOrEqualTo(2));
    expect(metrics.sampledAt, isNotNull);
    expect(metrics.sampledAt!.isAfter(firstSampleAt!), isTrue);

    metrics.stop();
    response.complete(http.Response('', 204));
    await Future<void>.delayed(Duration.zero);
    api.transport.session.telemetry.endMedia();
    api.transport.raw.close();
  });

  test(
    'getStats failure falls back and later samples recover while HTTP stalls',
    () async {
      final response = Completer<http.Response>();
      var posts = 0;
      final sender = _RecoveringStatsSender();
      final api = ApiClient(
        client: MockClient((_) {
          posts++;
          return response.future;
        }),
      );
      final track = _ScreenTrack(sender);
      final metrics = ScreenShareMetricsController(
        api,
        SessionScope(),
        readRoom: () => null,
        isSharing: () => true,
        readQuality: () => ScreenShareQuality.balanced,
        changed: () {},
      );

      metrics.start(track);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sender.requests, 1);
      expect(metrics.report?.state, 'waiting_first_frame');
      expect(metrics.sampledAt, isNull);
      expect(
        metrics.reportMeasurementFields['collection_state'],
        'unavailable',
      );
      await Future<void>.delayed(const Duration(milliseconds: 4550));

      expect(sender.requests, greaterThanOrEqualTo(3));
      expect(metrics.sampledAt, isNotNull);
      expect(metrics.report?.state, 'playing');
      expect(metrics.reportMeasurementFields['collection_state'], 'active');
      expect(posts, 1, reason: 'a stalled report must not queue later reports');

      metrics.stop();
      response.complete(http.Response('', 204));
      await Future<void>.delayed(Duration.zero);
      api.transport.raw.close();
    },
  );
}

class _StatsSender implements rtc.RTCRtpSender {
  int requests = 0;

  @override
  Future<List<rtc.StatsReport>> getStats() async {
    requests++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecoveringStatsSender implements rtc.RTCRtpSender {
  int requests = 0;

  @override
  Future<List<rtc.StatsReport>> getStats() {
    final request = requests++;
    if (request == 0) return Future.error(StateError('getStats failed'));
    final timestamp = 1000000.0 * request;
    final frames = request == 1 ? 10 : 25 + (request - 2) * 15;
    final bytes = request == 1 ? 1000 : 20000 + (request - 2) * 15000;
    return Future.value([
      rtc.StatsReport('outbound-video', 'outbound-rtp', timestamp, {
        'kind': 'video',
        'ssrc': 7,
        'active': true,
        'frameWidth': 1280,
        'frameHeight': 720,
        'framesEncoded': frames,
        'bytesSent': bytes,
        'packetsSent': frames,
      }),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScreenTrack implements LocalVideoTrack {
  _ScreenTrack(this.sender);

  @override
  final rtc.RTCRtpSender sender;

  @override
  Future<bool> stop() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
