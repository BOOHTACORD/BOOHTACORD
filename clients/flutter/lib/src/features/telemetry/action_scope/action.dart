import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import '../flow_contract/generated.dart';
import 'session.dart';
import '../../../app_version.dart';
part 'attributes.dart';

class ActionScope {
  ActionScope(
    this.name,
    this.session, {
    this.attempt = 1,
    String? flowId,
    this.enabled = false,
    this.observe,
    this.links = const [],
  }) : id = flowId ?? diagnosticId(),
       snapshot = session.snapshot() {
    if (enabled) {
      span = OTel.tracer().startSpan(
        name,
        context: Context.root,
        kind: SpanKind.internal,
        links: links,
      );
      decorate(span!, 'terminal', 'unknown');
    }
    emit('start', 'unknown');
    _timer = Timer(
      const Duration(seconds: 120),
      () => finish('timeout', reason: 'deadline'),
    );
    _unsubscribe = session.onReset(
      () => finish('superseded', reason: 'generation_changed'),
    );
  }
  final String name, id;
  final TelemetrySession session;
  final TelemetrySnapshot snapshot;
  final int attempt;
  final bool enabled;
  final List<SpanLink> links;
  final void Function(Map<String, Object>)? observe;
  Span? span;
  bool _ended = false;
  final _completion = <void Function()>{};

  bool get complete => _ended;
  String stage = 'intent';
  Timer? _timer;
  void Function()? _unsubscribe;
  static final Object _key = Object();
  static ActionScope? get current => Zone.current[_key] as ActionScope?;
  Future<T> run<T>(Future<T> Function() call) {
    if (_ended || !session.current(snapshot)) {
      final ambient = current;
      if (ambient == null ||
          (!ambient.complete && ambient.session.current(ambient.snapshot))) {
        return call();
      }
      return runZoned(() => Context.root.run(call), zoneValues: {_key: null});
    }
    return runZoned(
      () => enabled && span != null
          ? OTel.context(spanContext: span!.spanContext).run(call)
          : call(),
      zoneValues: {_key: this},
    );
  }

  void step(String value) {
    if (_ended ||
        !session.current(snapshot) ||
        !(flowFields['app.flow.stage']!['values'] as List).contains(value)) {
      return;
    }
    stage = value;
    emit('checkpoint', 'unknown');
  }

  void finish(String outcome, {String reason = 'none'}) {
    if (_ended) return;
    _ended = true;
    for (final callback in _completion.toList()) {
      try {
        callback();
      } catch (_) {}
    }
    _completion.clear();
    _timer?.cancel();
    _unsubscribe?.call();
    if (session.current(snapshot)) {
      observe?.call(fields('terminal', outcome));
      if (span != null) {
        decorate(span!, 'terminal', outcome);
        if ((flowFields['app.flow.reason']!['values'] as List).contains(
          reason,
        )) {
          span!.setStringAttribute('app.flow.reason', reason);
        }
        if ({'failed', 'timeout', 'rejected'}.contains(outcome)) {
          span!.setStatus(SpanStatusCode.Error);
        }
      }
    }
    final started = span?.startTime;
    final deadline = started?.add(const Duration(seconds: 120));
    final now = DateTime.now();
    span?.end(
      endTime: deadline != null && now.isAfter(deadline) ? deadline : now,
    );
  }

  ActionScope retry() => ActionScope(
    name,
    session,
    attempt: session.current(snapshot) && attempt < 20 ? attempt + 1 : 1,
    flowId: session.current(snapshot) && attempt < 20 ? id : null,
    enabled: enabled,
    observe: observe,
    links: session.current(snapshot) ? links : const [],
  );
}
