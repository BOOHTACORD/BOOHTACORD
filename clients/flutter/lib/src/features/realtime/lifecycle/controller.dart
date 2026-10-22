import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'delivery.dart';
import '../social_hints/hints.dart';
import 'events.dart';
import 'recovery.dart';

import 'package:flutter/foundation.dart';

import '../../../core/session/scope.dart';
import '../../../services/api_client.dart';
import 'event.dart';
import 'close.dart';
import '../../telemetry/action_scope/action.dart';
export 'connect.dart';
export 'close.dart';
export 'events.dart';
export 'recovery.dart';
export 'event.dart';

class RealtimeController extends ChangeNotifier {
  RealtimeController(
    this.api,
    this.scope, {
    required this.isReady,
    required this.expire,
    required this.invalidatePresence,
    required this.dispatch,
    this.recover,
    double Function()? jitter,
  }) : jitter = jitter ?? Random().nextDouble;
  final double Function() jitter;

  final ApiClient api;
  final SessionScope scope;
  final bool Function() isReady;
  final Future<void> Function() expire;
  final void Function() invalidatePresence;
  final FutureOr<void> Function(RealtimeEvent) dispatch;
  final FutureOr<void> Function()? recover;
  late final delivery = RealtimeDelivery(applyEvent, () async {
    if (recover != null) {
      await recover!();
    } else {
      await dispatch(
        const RealtimeEvent('recovery', 'connection.resync_required', {}),
      );
    }
    await SocialHints.forTransport(api.transport).receiveAsync(
      const RealtimeEvent('recovery', 'connection.resync_required', {}),
    );
  }, handleClosed);
  SessionTicket? deliveryTicket;
  int? deliveryServer;
  String? deliveryInstallation;
  Timer? readyTimeout;
  WebSocket? socket;
  StreamSubscription<dynamic>? subscription;
  Timer? retry;
  int attempt = 0;
  int generation = 0;
  bool connecting = false;
  bool connected = false;
  bool checkingSession = false;
  bool disposed = false;

  ActionScope? handshake;
  bool hadConnection = false;

  bool Function() admission() {
    final ticket = scope.capture();
    final current = generation;
    final server = api.transport.session.serverRevision;
    final installation = api.transport.session.telemetry.installation;
    return () =>
        !disposed &&
        ticket.isActive &&
        current == generation &&
        server == api.transport.session.serverRevision &&
        installation == api.transport.session.telemetry.installation &&
        isReady();
  }

  void changed() {
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
