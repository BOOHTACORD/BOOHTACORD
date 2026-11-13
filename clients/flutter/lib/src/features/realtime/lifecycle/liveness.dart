import 'dart:async';

import 'package:flutter/widgets.dart';

const heartbeatProtocol = 'boohtacord.heartbeat.v1';

class RealtimeLiveness with WidgetsBindingObserver {
  RealtimeLiveness(this.enabled, this.onTimeout, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final bool enabled;
  final void Function() onTimeout;
  final DateTime Function() now;
  Timer? _timer;
  DateTime? _lastSeen;
  bool _ready = false, _observing = false;

  bool observe(String kind, Map<String, dynamic> source) {
    if (kind == 'connection.heartbeat') {
      if (!enabled || !_ready || !_validHeartbeat(source)) return false;
    }
    if (!enabled) return true;
    if (kind == 'connection.ready') _ready = true;
    if (_ready &&
        (kind == 'connection.ready' || kind == 'connection.heartbeat')) {
      if (!_observing) {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      }
      _lastSeen = now();
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 45), _expire);
    }
    return true;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _ready = false;
    _lastSeen = null;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final last = _lastSeen;
    if (state == AppLifecycleState.resumed &&
        last != null &&
        now().difference(last) >= const Duration(seconds: 45)) {
      _expire();
    }
  }

  void _expire() {
    stop();
    onTimeout();
  }
}

bool _validHeartbeat(Map<String, dynamic> source) {
  final id = source['event_id'], time = source['occurred_at'];
  final payload = source['payload'];
  return source.length == 4 &&
      id is String &&
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(id) &&
      time is String &&
      DateTime.tryParse(time) != null &&
      payload is Map &&
      payload.isEmpty;
}
