import 'dart:convert';

import 'latest_writer.dart';

/// Metadata has its own queue and deadline; media lifecycle never awaits HTTP.
class ScreenDescriptorRuntime {
  ScreenDescriptorRuntime({
    required this.writer,
    required this.readConfirmed,
    required this.readIntent,
    required this.changed,
  });
  final LatestScreenProfileWriter writer;
  final Future<Map<String, Object?>?> Function() readConfirmed;
  final Map<String, Object?> Function() readIntent;
  final void Function() changed;
  ScreenDescriptorWriteStatus status = ScreenDescriptorWriteStatus.pending;
  DateTime? confirmedAt;
  DateTime? appliedAt;
  Map<String, Object?>? lastDescriptor;
  String? get descriptorJson =>
      lastDescriptor == null ? null : jsonEncode(lastDescriptor);
  Map<String, Object?>? _scope;
  bool Function()? _current;
  bool Function()? _captureCurrent;
  int _epoch = 0, _profileRevision = 0;
  String? _profileFingerprint;
  Future<void>? _reading;

  void recordWriteStatus(ScreenDescriptorWriteStatus value) {
    status = value;
    appliedAt = value == ScreenDescriptorWriteStatus.applied
        ? DateTime.now()
        : null;
  }

  void configurationChanged() {
    ++_epoch;
    writer.cancelPending();
    status = ScreenDescriptorWriteStatus.pending;
    confirmedAt = appliedAt = null;
    changed();
  }

  void activate(
    String lease,
    Map<String, Object?> scope,
    bool Function() current, {
    int operationRevision = 0,
    bool Function()? captureCurrent,
  }) {
    invalidate();
    _scope = Map.of(scope);
    _current = current;
    _captureCurrent = captureCurrent ?? current;
    writer.bind(lease, current, operationRevision: operationRevision);
  }

  Future<void> refresh() {
    if (_reading != null) return _reading!;
    final operation = _read(_epoch);
    _reading = operation;
    return operation.whenComplete(() {
      if (identical(_reading, operation)) _reading = null;
    });
  }

  Future<void> _read(int epoch) async {
    if (_scope == null ||
        _current?.call() != true ||
        _captureCurrent?.call() != true) {
      return;
    }
    Map<String, Object?>? profile;
    try {
      profile = await readConfirmed();
    } catch (_) {}
    if (epoch != _epoch ||
        _current?.call() != true ||
        _captureCurrent?.call() != true) {
      return;
    }
    if (profile == null) {
      // A previously confirmed pipeline is now unknown. Keep its descriptor
      // only as history, and prevent its late HTTP acknowledgement from
      // restoring freshness for the current pipeline.
      writer.cancelPending();
      confirmedAt = appliedAt = null;
      status = ScreenDescriptorWriteStatus.pending;
      changed();
      return;
    }
    final intent = readIntent();
    final fingerprint = jsonEncode([intent, profile]);
    if (_profileFingerprint != fingerprint) {
      _profileFingerprint = fingerprint;
      ++_profileRevision;
    }
    final encoding = profile['encoding'] as Map;
    final layers = encoding['layers'] as List;
    final descriptor = <String, Object?>{
      'schema_version': 1,
      'scope': {..._scope!, 'operation_revision': 0},
      ...intent,
      'publisher_state': 'sharing',
      'viewer_state': 'idle',
      'effective_profile': profile,
      'layer_topology': layers.length > 1
          ? 'bounded-simulcast'
          : 'single-layer',
      'profile_revision': _profileRevision,
      'capabilities': {
        'live_update': false,
        'republish_without_recapture': false,
        'simulcast': layers.length > 1,
      },
      'reason_codes': ['user-request'],
    };
    confirmedAt = DateTime.now();
    lastDescriptor = descriptor;
    writer.offer(descriptor);
    changed();
  }

  void stop() {
    ++_epoch;
    final previous = lastDescriptor;
    writer.cancelPending();
    if (previous != null && _current?.call() == true) {
      writer.offer({...previous, 'publisher_state': 'idle'});
    } else {
      writer.invalidate();
    }
    _scope = null;
    _current = null;
    _captureCurrent = null;
  }

  void invalidate() {
    ++_epoch;
    _scope = null;
    _current = null;
    _captureCurrent = null;
    lastDescriptor = null;
    confirmedAt = null;
    appliedAt = null;
    status = ScreenDescriptorWriteStatus.pending;
    _profileFingerprint = null;
    _profileRevision = 0;
    writer.invalidate();
  }
}
