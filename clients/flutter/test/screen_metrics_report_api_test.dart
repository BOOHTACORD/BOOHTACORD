import 'dart:async';
import 'dart:convert';

import 'package:boohtacord_desktop/src/screens/screen_receiver_diagnostics.dart';
import 'package:boohtacord_desktop/src/features/media/report_metrics/api.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/screen_receiver_report.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class AbortAwareHangingClient extends http.BaseClient {
  final requestReceived = Completer<http.AbortableRequest>();
  final requestAborted = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final abortable = request as http.AbortableRequest;
    requestReceived.complete(abortable);
    abortable.abortTrigger!.then((_) {
      if (!requestAborted.isCompleted) requestAborted.complete();
    });
    return requestAborted.future.then(
      (_) => throw http.RequestAbortedException(request.url),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443':
          'session=test-session',
    });
  });

  test(
    'posts normalized receiver measurements to the screen metrics API',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response('', 204);
        }),
      );
      final report = buildScreenReceiverReport(
        platform: 'android_native',
        selected: true,
        hasTrack: true,
        current: const ScreenReceiverSnapshot(
          timestampMs: 9000,
          bytesReceived: 2050000,
          framesDecoded: 260,
          framesRendered: 90,
          framesDropped: 7,
          jitterSeconds: 0.012,
          packetsLost: 6,
          frameWidth: 576,
          frameHeight: 1280,
          framesPerSecond: 0,
        ),
        metrics: const ScreenReceiverMetrics(
          bitrateKbps: 4000,
          decodedFps: 60,
          presentedFps: 20,
          droppedFrames: 3,
          jitterMs: 12,
          packetsLost: 6,
          packetLossPercent: 2,
        ),
        sampleAgeMs: 1000,
        packetLossWindowMs: 10000,
      );
      expect(report, isNotNull);

      const leaseId = '11111111-1111-4111-8111-111111111111';
      expect(api.transport.session.telemetry.bindMediaLease(leaseId), isTrue);

      await api.reportScreenShareMetrics(report!);

      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/voice/screen-metrics');
      expect(request.headers['origin'], 'https://v.bootybay.ru');
      expect(request.headers['cookie'], 'session=test-session');
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), {...report, 'voice_lease_id': leaseId});
      expect(request.body, isNot(contains('account_id')));
      expect(request.body, isNot(contains('channel_id')));
      expect(request.body, isNot(contains('track_id')));
    },
  );

  test('aborts a report request when the share generation stops', () async {
    final client = AbortAwareHangingClient();
    final api = ApiClient(client: client);
    final abort = Completer<void>();
    final operation = api.reportScreenShareMetrics(
      const {
        'platform': 'android_native',
        'direction': 'sender',
        'state': 'waiting_first_frame',
      },
      abortTrigger: abort.future,
      timeout: const Duration(seconds: 1),
    );
    await client.requestReceived.future;
    abort.complete();

    await expectLater(operation, throwsA(isA<ScreenMetricsReportAborted>()));
    await client.requestAborted.future;
  });

  test('aborts a hanging report when its HTTP deadline expires', () async {
    final client = AbortAwareHangingClient();
    final api = ApiClient(client: client);
    final operation = api.reportScreenShareMetrics(const {
      'platform': 'android_native',
      'direction': 'sender',
      'state': 'waiting_first_frame',
    }, timeout: const Duration(milliseconds: 10));

    await expectLater(operation, throwsA(isA<TimeoutException>()));
    await client.requestReceived.future;
    await client.requestAborted.future;
  });
}
