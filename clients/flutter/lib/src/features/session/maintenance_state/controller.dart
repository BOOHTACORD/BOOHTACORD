import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../services/api_client.dart';
import '../../realtime/lifecycle/event.dart';
import '../../realtime/lifecycle/maintenance_payload.dart';
import '../maintenance_socket/guest.dart';
import '../maintenance_socket/state.dart';

class MaintenanceController extends ChangeNotifier {
  MaintenanceController(
    this.api, {
    Future<WebSocket> Function()? openGuest,
    void Function()? abortGuest,
  }) {
    _guest = MaintenanceGuestSocket(
      _state,
      openGuest ?? api.openPublicRealtime,
      abortOpen:
          abortGuest ?? (openGuest == null ? api.abortPublicRealtime : null),
    );
    _state.addListener(_changed);
  }
  final ApiClient api;
  final _state = MaintenanceSocketState();
  late final MaintenanceGuestSocket _guest;
  bool _authenticated = false, _disposed = false;
  int _transition = 0;
  int? _authToken;

  bool get active => _state.active;
  set active(bool value) {
    _state.active = value;
    _state.known = true;
    _changed();
  }

  bool get known => _state.known;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void start() {
    unawaited(useGuest());
  }

  void restart() {
    unawaited(useGuest());
  }

  Future<void> useGuest() async {
    if (_disposed) return;
    final transition = ++_transition;
    _authenticated = false;
    final token = _authToken;
    _authToken = null;
    if (token != null) _state.end(token);
    await _guest.stop();
    if (!_disposed && transition == _transition && api.realtimeEnabled) {
      _guest.start();
    }
  }

  Future<void> useAuthenticated() async {
    if (_disposed) return;
    ++_transition;
    _authenticated = true;
    await _guest.stop();
  }

  Future<void> suspend() async {
    if (_disposed) return;
    _transition++;
    _authenticated = false;
    final token = _authToken;
    _authToken = null;
    if (token != null) _state.end(token);
    await _guest.stop();
  }

  void authSocketStart() {
    if (_disposed || !_authenticated) return;
    final previous = _authToken;
    if (previous != null) _state.end(previous);
    _authToken = _state.begin();
  }

  void authSocketEnd() {
    final token = _authToken;
    _authToken = null;
    if (token != null) _state.end(token);
  }

  bool acceptRealtimeEvent(RealtimeEvent event) {
    if (!isMaintenanceKind(event.kind)) return false;
    final token = _authToken;
    if (!_disposed && _authenticated && token != null) {
      _state.accept(token, event);
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _transition++;
    unawaited(_guest.stop().catchError((Object _) {}));
    _state.removeListener(_changed);
    _state.dispose();
    super.dispose();
  }
}
