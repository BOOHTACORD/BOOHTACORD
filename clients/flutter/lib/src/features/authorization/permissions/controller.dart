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
    if (!active || !scope.capture().isActive) return Future.value();
    return _inFlight ??= _load(_generation);
  }

  Future<void> _load(int generation) async {
    loading = true;
    error = null;
    notifyListeners();
    final operation = _inFlight;
    try {
      final next = await api.loadPermissions();
      if (generation == _generation && scope.capture().isActive)
        snapshot = next;
    } catch (cause) {
      if (generation == _generation) error = cause.toString();
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
      if (_inFlight == operation || generation == _generation) _inFlight = null;
    }
  }

  Future<void> refreshStrict() async {
    await refresh();
    if (error != null) throw StateError('Permission snapshot unavailable');
  }

  void stop() {
    _generation++;
    _poll?.cancel();
    _poll = null;
    _inFlight = null;
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
