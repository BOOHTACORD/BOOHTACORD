import 'dart:typed_data';

import '../features/telemetry/action_scope/session.dart';
import '../features/telemetry/action_scope/runtime.dart';
import '../features/telemetry/action_scope/sampling.dart';
import '../features/telemetry/export/session_processor.dart';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

typedef TraceSender = Future<void> Function(Uint8List body);

class ClientTelemetry {
  ClientTelemetry._();

  static bool enabled = false;
  static TelemetrySession? session;
  static void audioInputSwitch(String phase, String result) {
    if (!enabled ||
        !{'prejoin', 'active', 'reconnect'}.contains(phase) ||
        !{'success', 'fallback', 'error'}.contains(result)) {
      return;
    }
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
    if (!{'web', 'android', 'ios', 'windows', 'macos'}.contains(platform)) {
      return;
    }
    final span = OTel.tracer().startSpan(
      'audio.input.switch',
      kind: SpanKind.client,
    );
    span.setStringAttribute('platform', platform);
    span.setStringAttribute('phase', phase);
    span.setStringAttribute('result', result);
    if (result == 'error') span.setStatus(SpanStatusCode.Error);
    span.end();
  }

  static void desktopUpdate(
    String phase, {
    String? reason,
    String? version,
    int durationMs = 0,
  }) {
    const phases = {
      'check',
      'download',
      'verify',
      'stage',
      'ready',
      'apply',
      'restart',
      'restore',
      'completed',
      'rollback',
      'failed',
      'cancelled',
    };
    const reasons = {
      'signature',
      'publisher',
      'identity',
      'source',
      'digest',
      'size',
      'network',
      'http',
      'disk_space',
      'installation_location',
      'scope_changed',
      'cancelled',
      'native_apply',
      'bootstrap_identity',
      'other',
    };
    if (!enabled || !phases.contains(phase)) return;
    final platform = defaultTargetPlatform.name.toLowerCase();
    if (!{'macos', 'windows'}.contains(platform)) return;
    final span = OTel.tracer().startSpan(
      'desktop.update',
      kind: SpanKind.client,
    );
    span.setStringAttribute('platform', platform);
    span.setStringAttribute('phase', phase);
    if (reason != null)
      span.setStringAttribute(
        'reason',
        reasons.contains(reason) ? reason : 'other',
      );
    if (version != null &&
        RegExp(r'^\d{1,6}\.\d{1,6}\.\d{1,6}$').hasMatch(version))
      span.setStringAttribute('version', version);
    span.setIntAttribute('duration_ms', durationMs.clamp(0, 1800000));
    if (phase == 'failed') span.setStatus(SpanStatusCode.Error);
    span.end();
  }

  static Map<String, String> currentTraceHeaders() {
    final headers = <String, String>{};
    final span = Context.current.spanContext;
    if (enabled && span != null) injectTraceHeaders(headers, span);
    return headers;
  }

  static String? currentTraceparent() => currentTraceHeaders()['traceparent'];

  static void injectTraceHeaders(
    Map<String, String> headers,
    SpanContext span,
  ) {
    if (!span.isValid) return;
    W3CTraceContextPropagator().inject(
      OTel.context(spanContext: span),
      headers,
      _HeaderSetter(headers),
    );
  }

  static Future<void> initialize(TraceSender send) async {
    if (enabled || !telemetryConfigured) return;
    await OTel.initialize(
      serviceName: 'boohtacord-flutter',
      tracerName: 'boohtacord/client',
      sampler: configuredSampler(),
      spanProcessor: SessionSpanProcessor(send, () => session),
      enableMetrics: false,
      enableLogs: false,
      detectPlatformResources: false,
    );
    enabled = true;
  }

  static Future<T> trace<T>(
    String name,
    Future<T> Function() action, {
    bool Function()? failed,
  }) async {
    if (!enabled) return action();
    if (session != null) {
      return traceAction(
        name,
        session!,
        action,
        enabled: enabled,
        failed: failed,
      );
    }
    final span = OTel.tracer().startSpan(name, kind: SpanKind.client);
    span.addEventNow('app.client.$name.started');
    try {
      final result = await OTel.context(spanContext: span.spanContext)
          .run(action);
      if (failed?.call() ?? false) {
        span.setStatus(SpanStatusCode.Error);
        span.addEventNow('app.client.$name.failed');
      } else {
        span.addEventNow('app.client.$name.completed');
      }
      return result;
    } catch (_) {
      span.setStatus(SpanStatusCode.Error);
      span.addEventNow('app.client.$name.failed');
      rethrow;
    } finally {
      span.end();
    }
  }
}

class _HeaderSetter extends TextMapSetter<String> {
  _HeaderSetter(this.headers);
  final Map<String, String> headers;
  @override
  void set(String key, String value) => headers[key] = value;
}
