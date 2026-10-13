import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/http/transport.dart';

class ScreenProfileWriteAborted implements Exception {
  const ScreenProfileWriteAborted();
}

class ScreenProfileDescriptorApi {
  ScreenProfileDescriptorApi(this.transport);
  final ApiTransport transport;

  Future<void> update(
    String leaseId,
    Map<String, Object?> descriptor, {
    Duration timeout = const Duration(seconds: 5),
    Future<void>? abortTrigger,
  }) async {
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout');
    final body = jsonEncode(descriptor);
    if (utf8.encode(body).length > 4096) {
      throw ArgumentError('Screen descriptor exceeds the v1 body limit');
    }
    final abort = Completer<void>();
    var timedOut = false;
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    if (abortTrigger != null) {
      unawaited(abortTrigger.then((_) => cancel(), onError: (_) => cancel()));
    }
    final timer = Timer(timeout, () {
      timedOut = true;
      cancel();
    });
    Never aborted() {
      if (timedOut) throw TimeoutException('Screen descriptor HTTP deadline');
      throw const ScreenProfileWriteAborted();
    }

    Future<void> send() async {
      final headers = await transport.headers(jsonBody: true);
      if (abort.isCompleted) aborted();
      final request =
          http.AbortableRequest(
              'PUT',
              transport.uri(
                '/voice/leases/${Uri.encodeComponent(leaseId)}/screen-profile/v1',
              ),
              abortTrigger: abort.future,
            )
            ..headers.addAll(headers)
            ..followRedirects = false
            ..body = body;
      final response = await http.Response.fromStream(
        await transport.client.send(request),
      );
      if (abort.isCompleted) aborted();
      await transport.checked(response);
    }

    try {
      await Future.any<void>([
        send(),
        abort.future.then<void>((_) => aborted()),
      ]);
    } on http.RequestAbortedException {
      if (abort.isCompleted) aborted();
      rethrow;
    } finally {
      timer.cancel();
    }
  }
}
