import 'dart:async';
import 'dart:io';

class RealtimeOpenDeadline {
  RealtimeOpenDeadline(Future<WebSocket> pending, this.client) {
    timer = Timer(const Duration(seconds: 15), () {
      cancel(TimeoutException('Realtime upgrade deadline exceeded'));
    });
    unawaited(
      pending.then<void>(
        (socket) {
          if (result.isCompleted) {
            unawaited(socket.close());
          } else {
            timer.cancel();
            result.complete(socket);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) {
            timer.cancel();
            result.completeError(error, stack);
          }
        },
      ),
    );
  }

  final HttpClient client;
  final result = Completer<WebSocket>();
  late final Timer timer;

  void cancel([Object? reason]) {
    if (result.isCompleted) return;
    timer.cancel();
    client.close(force: true);
    result.completeError(reason ?? StateError('Realtime upgrade cancelled'));
  }
}
