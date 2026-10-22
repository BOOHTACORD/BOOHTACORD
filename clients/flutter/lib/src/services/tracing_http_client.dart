import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:http/http.dart' as http;

import 'client_telemetry.dart';
import '../features/telemetry/action_scope/session.dart';
import '../features/telemetry/action_scope/action.dart';
import '../features/telemetry/routine_request/trace.dart';

class TracingHttpClient extends http.BaseClient {
  TracingHttpClient(this.inner, [this.session]);

  final http.Client inner;
  final TelemetrySession? session;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final origin = session == null ? null : Uri.parse(session!.readOrigin());
    if (!ClientTelemetry.enabled ||
        (origin != null &&
            (request.url.origin != origin.origin ||
                !request.url.path.startsWith('${origin.path}/'))) ||
        request.url.path.endsWith('/telemetry/traces') ||
        request.url.path.endsWith('/screen-metrics')) {
      return inner.send(request);
    }
    final routine =
        ActionScope.current == null && routinePresenceRequest(request);
    final span = OTel.tracer().startSpan('api.request', kind: SpanKind.client);
    final method = request.method.toUpperCase();
    span.setStringAttribute(
      'http.request.method',
      const {
            'GET',
            'HEAD',
            'POST',
            'PUT',
            'PATCH',
            'DELETE',
            'OPTIONS',
          }.contains(method)
          ? method
          : 'OTHER',
    );
    ClientTelemetry.injectTraceHeaders(request.headers, span.spanContext);
    final action = ActionScope.current;
    if (action != null && action.session.current(action.snapshot)) {
      action.decorate(span, 'checkpoint', 'unknown');
      request.headers.addAll(action.headers());
    }
    try {
      final response = await inner.send(request);
      if (action?.name == 'realtime.process' && response.statusCode >= 400) {
        action?.finish(
          response.statusCode == 401 || response.statusCode == 403
              ? 'rejected'
              : 'failed',
          reason: response.statusCode == 401 || response.statusCode == 403
              ? 'permission_denied'
              : 'dependency',
        );
      }
      if (routine && response.statusCode < 400) omitSuccessfulPolling(span);
      span.setIntAttribute('http.response.status_code', response.statusCode);
      if (response.statusCode >= 500 ||
          (routine && response.statusCode >= 400)) {
        span.setStatus(SpanStatusCode.Error);
      }
      return response;
    } catch (_) {
      if (action?.name == 'realtime.process') {
        action?.finish('failed', reason: 'network');
      }
      span.setStatus(SpanStatusCode.Error);
      rethrow;
    } finally {
      span.end();
    }
  }

  @override
  void close() => inner.close();
}
