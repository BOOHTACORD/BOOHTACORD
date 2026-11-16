import 'dart:async';
import 'dart:convert';

import 'package:boohtacord_desktop/src/features/screen/metrics/telemetry_envelope.dart';
import 'package:boohtacord_desktop/src/features/screen/metrics/sender_report.dart';
import 'package:boohtacord_desktop/src/features/media/report_metrics/api.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443':
          'session=test-session',
    });
  });

  test('posts the ephemeral envelope under the active owner lease with auth and Origin', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response('', 204);
      }),
    );
    const scope = ScreenTelemetryPublicationScope(
      ownerLeaseId: '11111111-1111-4111-8111-111111111111',
      mediaSessionId: 'media-session-1',
      publicationGeneration: 2,
    );
    final envelope = buildFlutterScreenTelemetryEnvelope(
      scope: scope,
      platform: 'macos',
      report: const ScreenShareSenderReport(
        platform: 'macos_native',
        state: 'waiting_first_frame',
      ),
      measurementFields: const {'stats_source': 'unsupported'},
      sequence: 1,
      sampledAtMonotonicMs: null,
      nowMonotonicMs: 0,
    );

    await ScreenTelemetryReportApi(api.transport)
        .reportScreenTelemetry(scope.ownerLeaseId, envelope);

    expect(request.method, 'POST');
    expect(
      request.url.path,
      '/api/v1/voice/leases/11111111-1111-4111-8111-111111111111/screen-telemetry',
    );
    expect(request.headers['origin'], 'https://v.bootybay.ru');
    expect(request.headers['cookie'], 'session=test-session');
    expect(request.headers['content-type'], 'application/json');
    expect(jsonDecode(request.body), envelope);
    expect(request.body, isNot(contains('username')));
    expect(request.body, isNot(contains('track_id')));
  });

  test(
    'aborts an in-flight telemetry request when the sender generation stops',
    () async {
      final received = Completer<http.AbortableRequest>();
      final aborted = Completer<void>();
      final client = _HangingClient(received, aborted);
      final api = ApiClient(client: client);
      final stop = Completer<void>();
      const scope = ScreenTelemetryPublicationScope(
        ownerLeaseId: '11111111-1111-4111-8111-111111111111',
        mediaSessionId: 'media-session-1',
        publicationGeneration: 2,
      );
      final envelope = buildFlutterScreenTelemetryEnvelope(
        scope: scope,
        platform: 'windows',
        report: const ScreenShareSenderReport(
          platform: 'windows_native',
          state: 'playing',
        ),
        measurementFields: const {},
        sequence: 1,
        sampledAtMonotonicMs: null,
        nowMonotonicMs: 0,
      );
      final operation = ScreenTelemetryReportApi(api.transport)
          .reportScreenTelemetry(
            scope.ownerLeaseId,
            envelope,
            abortTrigger: stop.future,
          );
      await received.future;
      stop.complete();
      await expectLater(operation, throwsA(isA<ScreenMetricsReportAborted>()));
      await aborted.future;
    },
  );
}

class _HangingClient extends http.BaseClient {
  _HangingClient(this.received, this.aborted);
  final Completer<http.AbortableRequest> received;
  final Completer<void> aborted;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final value = request as http.AbortableRequest;
    received.complete(value);
    value.abortTrigger!.then((_) {
      if (!aborted.isCompleted) aborted.complete();
    });
    return aborted.future.then(
      (_) => throw http.RequestAbortedException(request.url),
    );
  }
}
