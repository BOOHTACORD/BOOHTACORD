import 'dart:async';
import 'dart:typed_data';

import '../sound_events/limit.dart';

typedef SoundItem = ({String kind, String? custom, int generation, int time});

class NativeSoundQueue {
  NativeSoundQueue(this.allowed, this.load, this.play, this.stop);
  final bool Function(String) allowed;
  final Future<Uint8List> Function(String) load;
  final Future<void> Function(String, Uint8List?, bool Function()) play;
  final void Function() stop;
  final _limit = SoundBurstLimit();
  int _generation = 0;
  bool _playing = false;
  SoundItem? _pending;
  void clear() {
    _generation++;
    _pending = null;
    stop();
  }

  void submit(String kind, {String? custom}) {
    if (!allowed(kind)) return;
    final item = (
      kind: kind,
      custom: custom,
      generation: _generation,
      time: DateTime.now().millisecondsSinceEpoch,
    );
    if (_playing) {
      _pending ??= item;
      return;
    }
    unawaited(_run(item));
  }

  Future<Uint8List?> _custom(String? id) async {
    if (id == null) return null;
    try {
      return await load(id).timeout(const Duration(milliseconds: 300));
    } catch (_) {
      return null;
    }
  }

  Future<void> _run(SoundItem item) async {
    bool current() =>
        item.generation == _generation &&
        allowed(item.kind) &&
        DateTime.now().millisecondsSinceEpoch - item.time < 5000;
    if (!current() || !_limit.allow(DateTime.now().millisecondsSinceEpoch)) {
      return;
    }
    _playing = true;
    try {
      final bytes = await _custom(item.custom);
      if (!current()) return;
      try {
        await play(item.kind, bytes, current);
      } catch (_) {
        if (bytes != null && current()) {
          await play(item.kind, null, current);
        }
      }
    } catch (_) {
      /* Failure must not affect the call. */
    } finally {
      _playing = false;
      final next = _pending;
      _pending = null;
      if (next != null) unawaited(_run(next));
    }
  }

  Future<void> preview(String id) async {
    final generation = _generation;
    if (!allowed('joined') || _playing) return;
    _playing = true;
    try {
      final bytes = await load(id);
      await play(
        'joined',
        bytes,
        () => generation == _generation && allowed('joined'),
      );
    } finally {
      _playing = false;
    }
  }
}
