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
  @override
  Future<WebSocket> openRealtime({String? after}) {
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
