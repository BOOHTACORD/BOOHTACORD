import 'dart:async';
import 'dart:typed_data';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import '../action_scope/action.dart';
import '../action_scope/session.dart';
import 'health.dart';
import '../routine_request/trace.dart';

part 'status.dart';
part 'delivery.dart';

class SessionSpanProcessor extends SpanProcessor {
  SessionSpanProcessor(this.send, this.readSession) {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      recordExportHealth(readSession());
      unawaited(forceFlush());
    });
  }
  final Future<void> Function(Uint8List) send;
  final TelemetrySession? Function() readSession;
  final _owners = Expando<_Owner>();
  final _queue = <Span>[];
  late final Timer _timer;
  Future<void>? _busy;
  bool _stopped = false;
  TelemetrySession? _watched;
  void Function()? _unwatch;
  @override
  Future<void> onStart(Span span, Context? parentContext) async {
    final action = ActionScope.current;
    // A late callback may still run inside the previous account's Dart Zone.
    // Never adopt its newly created child span as the replacement account.
    final stale =
        action != null &&
        (action.complete || !action.session.current(action.snapshot));
    if (stale &&
        (action.span == null ||
            span.spanContext.traceId == action.span!.spanContext.traceId)) {
      return;
    }
    // An explicit new root/action remains valid even inside an old callback.
    final session = !stale ? action?.session ?? readSession() : readSession();
    if (session == null) return;
    if (!identical(_watched, session)) {
      _unwatch?.call();
      _watched = session;
      _unwatch = session.onReset(dropStale);
    }
    final snapshot = session.snapshot();
    _owners[span] = _Owner(session, snapshot);
    if (snapshot.binding != null) {
      span.setStringAttribute('session.id', snapshot.binding!);
    }
  }

  @override
  Future<void> onEnd(Span span) async {
    if (successfulPolling(span)) return;
    final owner = _owners[span];
    if (_stopped ||
        owner == null ||
        owner.snapshot.binding == null ||
        !_current(span) ||
        _queue.length >= 128) {
      telemetryExportStatus.dropped++;
      return;
    }
    _queue.add(span);
    telemetryExportStatus.queued = _queue.length;
  }

  @override
  Future<void> onNameUpdate(Span span, String name) async {}
  @override
  Future<void> forceFlush() {
    if (_busy != null) return _busy!;
    final flush = _flush()
        .catchError((Object _) {})
        .whenComplete(() => _busy = null);
    _busy = flush;
    return flush;
  }

  @override
  Future<void> shutdown() async {
    _timer.cancel();
    _unwatch?.call();
    try {
      await forceFlush().timeout(const Duration(seconds: 3));
    } catch (_) {}
    _stopped = true;
    telemetryExportStatus.dropped += _queue.length;
    _queue.clear();
    telemetryExportStatus.queued = 0;
  }
}
