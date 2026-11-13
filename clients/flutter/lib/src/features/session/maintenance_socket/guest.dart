import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../realtime/lifecycle/event.dart';
import '../../realtime/lifecycle/liveness.dart';
import 'state.dart';

part 'guest_connection.dart';
part 'guest_events.dart';

class MaintenanceGuestSocket {
  MaintenanceGuestSocket(
    this.state,
    this.open, {
    Timer Function(Duration, void Function())? schedule,
    double Function()? jitter,
    this.abortOpen,
    this.initialTimeout = const Duration(seconds: 10),
  }) : schedule = schedule ?? Timer.new,
       jitter = jitter ?? Random().nextDouble;

  final MaintenanceSocketState state;
  final Future<WebSocket> Function() open;
  final Timer Function(Duration, void Function()) schedule;
  final double Function() jitter;
  final void Function()? abortOpen;
  final Duration initialTimeout;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _timeout, _retry;
  RealtimeLiveness? _liveness;
  bool _running = false, _connecting = false, _ready = false;
  int _epoch = 0, _attempt = 0;
  int? _token;
  Future<void> _closing = Future<void>.value();
  final Set<Future<void>> _openings = {};

  void start() {
    if (_running) return;
    _running = true;
    _attempt = 0;
    _beginConnect();
  }

  Future<void> stop() async {
    _running = false;
    _epoch++;
    if (_connecting) abortOpen?.call();
    _connecting = false;
    _ready = false;
    _liveness?.stop();
    _liveness = null;
    _timeout?.cancel();
    _timeout = null;
    _retry?.cancel();
    _retry = null;
    final token = _token;
    _token = null;
    if (token != null) state.end(token);
    await _closeActive();
    await _drainOpenings();
    await _closeActive();
  }
}
