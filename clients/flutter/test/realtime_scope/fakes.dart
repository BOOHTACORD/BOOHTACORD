import 'dart:async';
import 'dart:io';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/models.dart';

class RealtimeApiFake extends ApiClient {
  final opening = Completer<WebSocket>();
  final restored = Completer<SessionUser?>();
  final checking = Completer<void>();
  int opens = 0;
  String? after;
  Future<void>? abortSignal;
  @override
  Future<SessionUser?> currentRealtimeSession(
    Future<void> abort,
    bool Function() isCurrent,
  ) {
    abortSignal = abort;
    return currentSession();
  }

  @override
  Future<WebSocket> openRealtime({String? after, HttpClient? client}) {
    opens++;
    this.after = after;
    return opening.future;
  }

  @override
  Future<SessionUser?> currentSession() {
    checking.complete();
    return restored.future;
  }
}

class SocketFake extends Stream<dynamic> implements WebSocket {
  @override
  String? get protocol => null;
  final events = StreamController<dynamic>();
  bool closed = false;
  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    unawaited(events.close());
  }

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => events.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
