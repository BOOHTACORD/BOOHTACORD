import 'dart:async';

import 'client.dart';
import '../../screen/rollout/policy.dart';

/// Keeps the server-owned LiveKit Egress capture alive. Screenshot bytes stay local.
class LatestScreenPreviewUploader {
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
  String? _lease, _generation;
  DateTime? _lastBeginAt;
  int _epoch = 0;
  Future<void>? _beginning, _stopping;

  void _switchLease(String lease) {
    final oldLease = _lease, oldGeneration = _generation;
    final epoch = ++_epoch;
    _lease = lease;
    _generation = null;
    _lastBeginAt = null;
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
      if (previous != null && previous != generation) {
        await client.invalidate(lease, previous).catchError((_) {});
      }
    } catch (_) {
      // The next 30-second screen sample retries the server lease request.
    } finally {
      if (epoch == _epoch) _beginning = null;
    }
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
    _lastBeginAt = null;
    final beginning = _beginning;
    await beginning?.catchError((_) {});
    if (lease != null && generation != null) {
      await client.invalidate(lease, generation).catchError((_) {});
    }
  }
}
