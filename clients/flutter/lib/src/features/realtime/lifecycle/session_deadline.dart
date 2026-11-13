import 'dart:async';

import '../../../models.dart';

class RealtimeSessionDeadline {
  RealtimeSessionDeadline(
    Future<SessionUser?> Function(Future<void>, bool Function()) start,
  ) {
    timer = Timer(const Duration(seconds: 10), cancel);
    unawaited(
      Future.sync(() => start(aborted.future, () => !result.isCompleted))
          .then<void>(
            (value) {
              if (!result.isCompleted) {
                timer.cancel();
                result.complete(value);
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

  final aborted = Completer<void>();
  final result = Completer<SessionUser?>();
  late final Timer timer;

  void cancel() {
    if (result.isCompleted) return;
    timer.cancel();
    aborted.complete();
    result.completeError(TimeoutException('Realtime session check cancelled'));
  }
}
