import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../services/audio_device_check.dart';
import '../../../services/android_audio_devices.dart';
import '../../../services/sound_engine_lease.dart';
import 'pcm.dart';

class NativeSoundPlayer {
  int _generation = 0;
  SoundHandle? _handle;
  void stop() {
    _generation++;
    final handle = _handle;
    _handle = null;
    if (handle != null && SoLoud.instance.isInitialized) {
      unawaited(SoLoud.instance.stop(handle).catchError((Object _) {}));
    }
  }

  Future<void> play(
    String kind,
    Uint8List? bytes,
    int volume,
    String? output,
    String? label,
    bool Function() active,
  ) async {
    final generation = _generation;
    bool current() => active() && generation == _generation;
    if (!current()) return;
    final engine = SoLoud.instance;
    // The local speaker test owns the same engine. Never take it over.
    if (engine.isInitialized) {
      throw StateError('Звуковой выход занят проверкой.');
    }
    AudioSource? source;
    final release = SoundEngineLease.acquire();
    if (release == null) throw StateError('Звуковой выход занят.');
    var started = false, initialized = false;
    try {
      if (AndroidAudioDevices.isAndroid &&
          AndroidAudioDevices.isNativeOutputRoute(output)) {
        if (!await AndroidAudioDevices.selectNativeOutput(output!)) {
          throw StateError('Аудиовыход недоступен.');
        }
      }
      final device = resolvePlaybackDevice(
        selectedId: output,
        selectedLabel: label,
        available: engine.listPlaybackDevices(),
      );
      if (!current()) return;
      await engine.init(device: device);
      initialized = true;
      source = await engine.loadMem('voice-cue', bytes ?? defaultSound(kind));
      if (!current()) return;
      _handle = engine.play(source, volume: volume.clamp(0, 100) / 100);
      started = true;
      final end = DateTime.now().add(const Duration(milliseconds: 3200));
      while (current() &&
          DateTime.now().isBefore(end) &&
          engine.getIsValidVoiceHandle(_handle!)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    } catch (_) {
      if (!started && current()) rethrow;
    } finally {
      try {
        if (initialized && engine.isInitialized) {
          final handle = _handle;
          _handle = null;
          if (handle != null) await engine.stop(handle);
          if (source != null) await engine.disposeSource(source);
          await engine.deinitAsync();
        }
      } finally {
        release();
      }
    }
  }
}
