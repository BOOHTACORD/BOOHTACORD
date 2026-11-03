import 'dart:async';

import 'client.dart';
import '../../screen/rollout/policy.dart';

/// Keeps the server-owned LiveKit Egress capture alive. Screenshot bytes stay local.
class LatestScreenPreviewUploader {
  static const _beginRetryDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  LatestScreenPreviewUploader(
    this.client, {
    bool? enabled,
    DateTime Function()? now,
    Duration refreshInterval = const Duration(seconds: 30),
  }) : enabled = enabled ?? const ScreenMediaRollout().jpegPreview,
       _now = now ?? DateTime.now,
       _refreshInterval = refreshInterval;

  final ScreenPreviewClient client;
  final bool enabled;
  final DateTime Function() _now;
  final Duration _refreshInterval;

  Timer? _refreshTimer;
  Timer? _retryTimer;
  String? _lease, _generation;
  DateTime? _lastBeginAt;
  int _epoch = 0, _retryAttempt = 0;
  Future<void>? _beginning, _stopping;

  void _switchLease(String lease) {
    final oldLease = _lease, oldGeneration = _generation;
    final epoch = ++_epoch;
    _lease = lease;
    _generation = null;
    _lastBeginAt = null;
    _retryAttempt = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (_lease == lease) unawaited(start(lease).catchError((_) {}));
    });
    if (oldLease != null && oldGeneration != null) {
      unawaited(client.invalidate(oldLease, oldGeneration).catchError((_) {}));
    }
    _beginning = _begin(lease, epoch);
  }

  Future<void> _begin(String lease, int epoch) async {
    _lastBeginAt = _now();
    try {
      final generation = await client.begin(lease);
      if (epoch != _epoch || lease != _lease) {
        await client.invalidate(lease, generation).catchError((_) {});
        return;
      }
      final previous = _generation;
      _generation = generation;
      _retryAttempt = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      if (previous != null && previous != generation) {
        await client.invalidate(lease, previous).catchError((_) {});
      }
    } catch (_) {
      _scheduleBeginRetry(lease, epoch);
    } finally {
      if (epoch == _epoch) _beginning = null;
    }
  }

  void _scheduleBeginRetry(String lease, int epoch) {
    if (epoch != _epoch || lease != _lease || _retryTimer != null) return;
    final delay = _beginRetryDelays[_retryAttempt];
    if (_retryAttempt < _beginRetryDelays.length - 1) _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (epoch == _epoch && lease == _lease) {
        unawaited(start(lease).catchError((_) {}));
      }
    });
  }

  Future<void> start(String lease) async {
    if (!enabled) return;
    if (_lease != lease) {
      _switchLease(lease);
    } else if (_beginning == null &&
        (_generation == null ||
            _lastBeginAt == null ||
            _now().difference(_lastBeginAt!) >= _refreshInterval)) {
      _beginning = _begin(lease, _epoch);
    }
    await _beginning;
  }

  Future<void> stop() {
    final existing = _stopping;
    if (existing != null) return existing;
    final operation = _stop();
    late final Future<void> shared;
    shared = operation.whenComplete(() {
      if (identical(_stopping, shared)) _stopping = null;
    });
    _stopping = shared;
    return shared;
  }

  Future<void> _stop() async {
    final lease = _lease, generation = _generation;
    ++_epoch;
    _lease = _generation = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _lastBeginAt = null;
    final beginning = _beginning;
    await beginning?.catchError((_) {});
    if (lease != null && generation != null) {
      await client.invalidate(lease, generation).catchError((_) {});
    }
  }
}
