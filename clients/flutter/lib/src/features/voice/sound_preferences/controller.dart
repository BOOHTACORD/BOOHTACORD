import 'package:flutter/foundation.dart';

import 'fence.dart';
import 'pending.dart';
import 'remote.dart';
import 'schema.dart';

class VoiceSoundController extends ChangeNotifier {
  VoiceSoundController(this.remote, this.fence, this.active);
  final VoiceSoundRemote remote;
  final SoundPreferenceFence fence;
  final bool Function() active;
  Map<String, dynamic> _settings = mutedSoundSettings();
  Map<String, dynamic> get settings => Map.unmodifiable(_settings);
  bool unsynchronised = false, _closed = false, _failed = false;
  int? _revision;
  int _pending = 0;
  int _epoch = 0;
  Future<void> _tail = Future.value();
  bool get _current => !_closed && active();
  void _changed() {
    if (_current) notifyListeners();
  }

  Future<void> load() async {
    if (_revision != null && (unsynchronised || _pending > 0)) return;
    final epoch = ++_epoch;
    try {
      final data = await remote.load();
      final restricted = await fence.apply(data.settings);
      if (!_current || epoch != _epoch) return;
      _revision = data.revision;
      _settings = restricted;
      unsynchronised =
          _failed || _pending > 0 || !mapEquals(restricted, data.settings);
    } catch (_) {
      if (_current && epoch == _epoch) unsynchronised = true;
    }
    _changed();
  }

  Future<void> update(Map<String, dynamic> values) {
    final change = Map<String, dynamic>.of(values);
    validateSoundChanges(change);
    if (!_current) return Future.value();
    if (_revision == null) {
      _epoch++;
      _failed = true;
      unsynchronised = true;
      _changed();
      return preserveBeforeLoad(fence, change);
    }
    _epoch++;
    final before = Map<String, dynamic>.of(_settings);
    for (final entry in change.entries) {
      if (soundFlags.contains(entry.key) && entry.value == false) {
        _settings[entry.key] = false;
      }
      if (entry.key == 'volume' &&
          (entry.value as int) < (_settings['volume'] as int)) {
        _settings['volume'] = entry.value;
      }
    }
    _pending++;
    unsynchronised = true;
    _changed();
    final receipt = fence
        .restrict(change, before)
        .then<SoundFenceReceipt?>(
          (value) => value,
          onError: (Object _, StackTrace stack) => null,
        );
    final result = _tail.then((_) => _save(change, receipt));
    _tail = result;
    return result;
  }

  Future<void> _save(
    Map<String, dynamic> change,
    Future<SoundFenceReceipt?> pending,
  ) async {
    try {
      final receipt = await pending;
      if (receipt == null) throw StateError('Unable to persist mute');
      if (!_current || _revision == null) return;
      final result = await remote.patch(_revision!, change);
      if (!_current) return;
      await fence.acknowledge(receipt);
      final restricted = await fence.apply(result.settings);
      if (!_current) return;
      _revision = result.revision;
      _settings = restricted;
      unsynchronised =
          _failed || _pending > 1 || !mapEquals(restricted, result.settings);
    } catch (_) {
      if (_current) {
        _failed = true;
        unsynchronised = true;
      }
    } finally {
      if (_current) {
        _pending--;
        _changed();
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
