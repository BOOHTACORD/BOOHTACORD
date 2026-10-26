import 'dart:async';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/client_telemetry.dart';
import 'package:boohtacord_desktop/src/services/tracing_http_client.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/session.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/failure.dart';
import 'package:boohtacord_desktop/src/features/telemetry/export/session_processor.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/opentelemetry_proto_dart.dart'
    as proto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('deadline timeout is distinct from network failure', () {
    expect(failureOutcome(TimeoutException('private deadline')), (
      outcome: 'timeout',
      reason: 'deadline',
    ));
  });
  test('routine successes do not export, failures and stop transitions remain diagnostic', () async {
    final exports = <Uint8List>[];
    ClientTelemetry.session = TelemetrySession(
      SessionScope().capture,
      () => 'https://synthetic.invalid/api/v1',
    );
    ClientTelemetry.session!.bind('1' * 32, '1');
    final processor = SessionSpanProcessor(
      (body) async => exports.add(body),
      () => ClientTelemetry.session,
    );
    await OTel.initialize(
      serviceName: 'synthetic-qa',
      tracerName: 'qa',
      spanProcessor: processor,
      enableMetrics: false,
      enableLogs: false,
      detectPlatformResources: false,
    );
    ClientTelemetry.enabled = true;
    addTearDown(() async {
      await OTel.shutdown();
      ClientTelemetry.enabled = false;
      ClientTelemetry.session = null;
    });
    var status = 204, timeout = false;
    final client = TracingHttpClient(
      MockClient((request) async {
        if (timeout) throw TimeoutException('private network address');
        return http.Response('', status);
      }),
      ClientTelemetry.session,
    );
    final uri = Uri.parse(
      'https://synthetic.invalid/api/v1/voice/leases/private-viewer/screen-viewers/private-owner',
    );
    for (var i = 0; i < 12; i++) {
      await client.get(uri);
      await client.put(uri);
      await client.get(
        Uri.parse('https://synthetic.invalid/api/v1/auth/session'),
      );
    }
    await processor.forceFlush();
    expect(exports, isEmpty);
    await ClientTelemetry.trace('voice.join', () async {
      await client.put(uri);
    });
    status = 503;
    await client.put(uri);
    timeout = true;
    await expectLater(client.get(uri), throwsA(isA<TimeoutException>()));
    timeout = false;
    status = 204;
    await client.delete(uri);
    await processor.forceFlush();
    final spans = exports
        .expand(
          (b) => proto.ExportTraceServiceRequest.fromBuffer(b).resourceSpans,
        )
        .expand((r) => r.scopeSpans)
        .expand((s) => s.spans)
        .where((s) => s.name == 'api.request')
        .toList();
    expect(spans, hasLength(4));
    expect(spans.skip(1).take(2).every((s) => s.status.code.value == 2), true);
    expect(
      spans.expand((s) => s.attributes).map((a) => a.value.stringValue).join(),
      isNot(contains('private-')),
    );
  });
}
