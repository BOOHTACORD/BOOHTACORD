import 'dart:async';
import 'dart:math';

import 'desktop/coordinator.dart';

import 'package:flutter/widgets.dart';

import 'api.dart';
import 'evaluator.dart';
import 'identity.dart';
import 'preferences.dart';

enum UpdateCheckStatus { idle, checking, ok, error }

class UpdateController extends ChangeNotifier with WidgetsBindingObserver {
  UpdateController({
    required this.api,
    required this.identity,
    UpdatePreferences? preferences,
    Random? random,
    this.desktop,
    String Function()? scopeKey,
  }) : preferences = preferences ?? UpdatePreferences(),
       _random = random ?? Random(),
       scopeKey = scopeKey ?? api.baseUrl {
    desktop?.addListener(notifyListeners);
  }
  factory UpdateController.disabled() => UpdateController(
    api: UpdateApi(baseUrl: () => 'https://invalid.local'),
    identity: const NativeUpdateIdentity(
      LocalUpdateIdentity(
        releaseId: 'disabled',
        releaseOrder: 1,
        platform: 'windows',
      ),
      UpdateSelector.windows('x64'),
      UpdateEnvironment(osVersion: '0', arch: 'x64'),
    ),
  );
  final DesktopUpdateCoordinator? desktop;
  final String Function() scopeKey;
  final UpdateApi api;
  final NativeUpdateIdentity identity;
  final UpdatePreferences preferences;
  final Random _random;
  UpdateCheckStatus status = UpdateCheckStatus.idle;
  UpdateResult? result;
  UpdatePolicy? policy;
  bool stale = false;
  bool visible = false;
  String? error;
  DateTime? lastSuccessfulCheckAt;
  Future<void> Function()? onLocalBootstrap;
  bool _localBootstrapAcknowledged = false;
  Future<void> acknowledgeLocalBootstrap() async {
    if (_localBootstrapAcknowledged) return;
    _localBootstrapAcknowledged = true;
    await WidgetsBinding.instance.endOfFrame;
    await onLocalBootstrap?.call();
  }

  Timer? _timer;
  int _failures = 0;
  DateTime? _lastAttempt;
  DateTime? _manualAfter;
  bool _disposed = false;
  bool _foreground = true;
  Duration _serverDelay = Duration.zero;

  void invalidateScope() {
    desktop?.scopeChanged();
    policy = null;
    result = null;
    visible = false;
    stale = false;
    notifyListeners();
  }

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _schedule(Duration(milliseconds: _random.nextInt(5001)));
  }

  Future<void> check() async {
    if (_disposed || status == UpdateCheckStatus.checking) return;
    status = UpdateCheckStatus.checking;
    error = null;
    _lastAttempt = DateTime.now();
    notifyListeners();
    try {
      final origin = api.baseUrl(), scope = scopeKey();
      final next = await api.fetch(identity.selector);
      if (origin != api.baseUrl() || scope != scopeKey()) {
        status = UpdateCheckStatus.idle;
        return;
      }
      if ((next.revision ?? 0) < (policy?.revision ?? 0)) {
        status = UpdateCheckStatus.ok;
        return;
      }
      policy = next;
      result = evaluateUpdate(identity.local, next, identity.environment);
      final target = next.target;
      visible =
          result == UpdateResult.updateAvailable &&
          target != null &&
          !await preferences.isSnoozed(
            api.baseUrl(),
            identity.selector,
            target.releaseId,
            target.priority ?? 'normal',
          );
      await desktop?.restorePrepared(target);
      stale = false;
      status = UpdateCheckStatus.ok;
      _failures = 0;
      _serverDelay = Duration.zero;
      lastSuccessfulCheckAt = DateTime.now();
    } catch (cause) {
      stale = result != null;
      status = UpdateCheckStatus.error;
      error = 'Не удалось проверить обновление.';
      _serverDelay = cause is UpdateApiFailure
          ? cause.retryAfter ?? Duration.zero
          : Duration.zero;
      _failures = min(_failures + 1, 4);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void manual() {
    if (_manualAfter?.isAfter(DateTime.now()) == true ||
        status == UpdateCheckStatus.checking)
      return;
    _manualAfter = DateTime.now().add(const Duration(seconds: 5));
    check().catchError((Object _) {});
  }

  Future<void> later() async {
    final target = policy?.target;
    if (target == null) return;
    await preferences.snooze(
      api.baseUrl(),
      identity.selector,
      target.releaseId,
      target.priority ?? 'normal',
    );
    visible = false;
    notifyListeners();
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    if (_disposed || !_foreground) return;
    _timer = Timer(delay, () async {
      try {
        await check();
      } catch (_) {
      } finally {
        final seconds = _failures == 0
            ? 300
            : [30, 60, 120, 300][_failures - 1];
        final calculated = Duration(
          milliseconds: (seconds * 1000 * (.9 + _random.nextDouble() * .2))
              .round(),
        );
        _schedule(_serverDelay > calculated ? _serverDelay : calculated);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _timer?.cancel();
      return;
    }
    final elapsed = _lastAttempt == null
        ? const Duration(days: 1)
        : DateTime.now().difference(_lastAttempt!);
    _schedule(
      elapsed > const Duration(seconds: 60)
          ? Duration.zero
          : const Duration(seconds: 60) - elapsed,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    desktop?.removeListener(notifyListeners);
    desktop?.dispose();
    super.dispose();
  }
}
