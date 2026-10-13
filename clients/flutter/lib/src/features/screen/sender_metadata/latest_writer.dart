import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/http/api_failure.dart';

typedef ScreenDescriptorWrite = Future<void> Function(
  String leaseId,
  Map<String, Object?> descriptor,
  Future<void> abort,
);

enum ScreenDescriptorWriteStatus { pending, applied, unavailable }

typedef _ScreenDescriptorRecovery = ({
  Map<String, Object?> value,
  String fingerprint,
  int epoch,
  Duration eligibleAt,
});

Duration Function() _monotonicClock() {
  final watch = Stopwatch()..start();
  return () => watch.elapsed;
}

/// One in-flight request and one latest queued descriptor. Each retryable wave
/// has at most two HTTP attempts. While the same owner/configuration is active,
/// later offers may resume its identical payload/revision after a monotonic
/// cooldown (five seconds by default); there is no fixed lifetime attempt budget.
/// Recovery has no timer and never awaits media operations. If offers stop, such
/// as after an idle clear, only that wave runs. Permanent/ACL errors stay latched
/// for unchanged state; new semantics or an explicit boundary clear recovery.
class LatestScreenProfileWriter {
  LatestScreenProfileWriter(
    this.write, {
    required this.changed,
    this.retryDelay = const Duration(milliseconds: 200),
    this.recoveryCooldown = const Duration(seconds: 5),
    Duration Function()? monotonicElapsed,
  }) : _elapsed = monotonicElapsed ?? _monotonicClock() {
    if (recoveryCooldown < Duration.zero) {
      throw ArgumentError.value(recoveryCooldown, 'recoveryCooldown');
    }
  }
  final ScreenDescriptorWrite write;
  final void Function(ScreenDescriptorWriteStatus) changed;
  final Duration retryDelay, recoveryCooldown;
  final Duration Function() _elapsed;
  String? _lease, _fingerprint;
  bool Function()? _current;
  int _epoch = 0, _revision = 0;
  final Map<String, int> _leaseRevisions = {};
  Map<String, Object?>? _queued;
  Future<void>? _running;
  Completer<void>? _abort;
  _ScreenDescriptorRecovery? _recovery;

  void bind(
    String leaseId,
    bool Function() isCurrent, {
    int operationRevision = 0,
  }) {
    if (_lease != leaseId) {
      invalidate();
      _lease = leaseId;
    }
    _current = isCurrent;
    final previous = _leaseRevisions[leaseId] ?? 0;
    _revision = previous > operationRevision ? previous : operationRevision;
    _leaseRevisions[leaseId] = _revision;
  }

  void offer(Map<String, Object?> descriptor) {
    if (_lease == null) return;
    if (_current?.call() != true) {
      _recovery = null;
      return;
    }
    // Clone at the boundary: callers must not mutate a queued request.
    final snapshot = jsonDecode(jsonEncode(descriptor)) as Map<String, Object?>;
    final fingerprint = jsonEncode(snapshot);
    if (fingerprint == _fingerprint) {
      final recovery = _recovery;
      if (recovery == null) return;
      if (recovery.epoch != _epoch || recovery.fingerprint != fingerprint) {
        _recovery = null;
        return;
      }
      if (_elapsed() < recovery.eligibleAt) return;
      // Existing active-pipeline offers trigger recovery; no background timer.
      // Reuse the immutable failed payload/revision for server idempotence.
      _recovery = null;
      _queued = recovery.value;
      changed(ScreenDescriptorWriteStatus.pending);
      _drain();
      return;
    }
    _recovery = null;
    final scope = snapshot['scope'];
    if (scope is! Map<String, Object?>) throw ArgumentError('Descriptor scope');
    scope['operation_revision'] = ++_revision;
    _leaseRevisions[_lease!] = _revision;
    _fingerprint = fingerprint;
    _queued = snapshot;
    changed(ScreenDescriptorWriteStatus.pending);
    _drain();
  }

  void invalidate() {
    ++_epoch;
    _recovery = null;
    _abort?.complete();
    _abort = null;
    _lease = _fingerprint = null;
    _current = null;
    _queued = null;
  }

  void cancelPending() {
    ++_epoch;
    _recovery = null;
    _abort?.complete();
    _abort = null;
    _queued = null;
    _fingerprint = null;
  }

  void _drain() {
    if (_running != null || _queued == null) return;
    _running = _sendLatest().whenComplete(() {
      _running = null;
      _drain();
    });
  }

  Future<void> _sendLatest() async {
    final value = _queued!, lease = _lease!, epoch = _epoch;
    final fingerprint = _fingerprint!;
    _queued = null;
    final abort = Completer<void>();
    _abort = abort;
    bool current() => epoch == _epoch && _current?.call() == true;
    try {
      for (var attempt = 0; attempt < 2 && current(); attempt++) {
        try {
          await write(lease, value, abort.future);
          if (current() && _queued == null) {
            changed(ScreenDescriptorWriteStatus.applied);
          }
          return;
        } catch (error) {
          if (!current()) return;
          final retry =
              error is TimeoutException ||
              (error is! http.RequestAbortedException &&
                  (error is SocketException ||
                      error is http.ClientException)) ||
              (error is ApiFailure && (error.status ?? 0) >= 500);
          if (!retry || attempt == 1 || _queued != null) {
            if (_queued == null) {
              if (retry && _fingerprint == fingerprint) {
                // At most two HTTP attempts per wave. While ownership remains
                // current, future offers may start another wave after cooldown;
                // this is recovery, not a fixed lifetime attempt budget.
                _recovery = (
                  value: jsonDecode(jsonEncode(value)) as Map<String, Object?>,
                  fingerprint: fingerprint,
                  epoch: epoch,
                  eligibleAt: _elapsed() + recoveryCooldown,
                );
              }
              changed(ScreenDescriptorWriteStatus.unavailable);
            }
            return;
          }
          await Future.any<void>([
            Future<void>.delayed(retryDelay),
            abort.future,
          ]);
        }
      }
    } finally {
      if (identical(_abort, abort)) _abort = null;
    }
  }

  Future<void> flush() async {
    while (_running != null) {
      await _running;
    }
  }
}
