import 'dart:async';
import 'dart:convert';

import '../../../core/http/transport.dart';
import '../../telemetry/media_sample/record.dart';

import 'package:http/http.dart' as http;

class ScreenMetricsReportAborted implements Exception {
  const ScreenMetricsReportAborted();
}

class ScreenMetricsReportApi {
  ScreenMetricsReportApi(this.transport);
  final ApiTransport transport;

  Future<void> reportScreenShareMetrics(
    Map<String, Object> report, {
    Duration timeout = const Duration(seconds: 10),
    Future<void>? abortTrigger,
  }) async {
    final abort = Completer<void>();
    var timedOut = false;
    void completeAbort() {
      if (!abort.isCompleted) abort.complete();
    }

    if (abortTrigger != null) {
      unawaited(abortTrigger.then((_) => completeAbort()));
    }
    final timer = Timer(timeout, () {
      timedOut = true;
      completeAbort();
    });
    Future<void> send() async {
      final session = transport.session.telemetry;
      final owner = session.snapshot();
      final headers = await transport.headers(jsonBody: true);
      if (abort.isCompleted) _throwAbort(timedOut);
      final request =
          http.AbortableRequest(
              'POST',
              transport.uri('/voice/screen-metrics'),
              abortTrigger: abort.future,
            )
            ..headers.addAll(headers)
            ..body = jsonEncode({
              ...report,
              if (owner.leaseId != null) 'voice_lease_id': owner.leaseId!,
            });
      recordMediaSample(report, session, owner);
      final response = await http.Response.fromStream(
        await transport.client.send(request),
      );
      await transport.checked(response);
    }

    final abortOutcome = abort.future.then<void>((_) => _throwAbort(timedOut));
    try {
      await Future.any<void>([send(), abortOutcome]);
    } finally {
      timer.cancel();
    }
  }

  Never _throwAbort(bool timedOut) {
    if (timedOut) throw TimeoutException('Screen metrics report timed out');
    throw const ScreenMetricsReportAborted();
  }
}
