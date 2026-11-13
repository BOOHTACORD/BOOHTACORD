import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/session/scope.dart';
import '../../../services/api_client.dart';
import 'model.dart';

class PermissionController extends ChangeNotifier {
  PermissionController(this.api, this.scope);
  final ApiClient api;
  final SessionScope scope;
  PermissionSnapshot? snapshot;
  String? error;
  bool loading = false;
  Timer? _poll;
  Future<void>? _inFlight;
  SessionTicket? _inFlightTicket;
  int _generation = 0;
  bool get active => _poll != null;
  bool allows(GuildPermission permission) =>
      snapshot?.allows(permission) ?? false;

  Future<void> start() async {
    stop();
    _poll = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(refresh()),
    );
    await refresh();
  }

  Future<void> refresh() {
    final ticket = scope.capture();
    if (!active || !ticket.isActive) return Future.value();
    if (_inFlight != null && !(_inFlightTicket?.isActive ?? false)) {
      _generation++;
      _inFlight = null;
      snapshot = null;
    }
    if (_inFlight != null) return _inFlight!;
    _inFlightTicket = ticket;
    return _inFlight = _load(_generation, ticket);
  }

  Future<void> _load(int generation, SessionTicket ticket) async {
    loading = true;
    error = null;
    notifyListeners();
    final operation = _inFlight;
    try {
      final next = await api.loadPermissions();
      if (generation == _generation && ticket.isActive) {
        snapshot = next;
      }
    } catch (cause) {
      if (generation == _generation && ticket.isActive) error = cause.toString();
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
      if (_inFlight == operation || generation == _generation) {
        _inFlight = null;
        _inFlightTicket = null;
      }
    }
  }

  Future<void> refreshStrict() async {
    final ticket = scope.capture();
    if (!active || !ticket.isActive) return;
    final generation = ++_generation;
    _inFlight = null;
    await refresh();
    if (generation != _generation || !ticket.isActive || error != null) {
      throw StateError('Permission snapshot unavailable');
    }
  }

  void stop() {
    _generation++;
    _poll?.cancel();
    _poll = null;
    _inFlight = null;
    _inFlightTicket = null;
    snapshot = null;
    error = null;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
