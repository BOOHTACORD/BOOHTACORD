import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

import 'android_audio_devices.dart';
import 'sound_engine_lease.dart';

/// Local-only microphone and speaker checks used by audio settings.
/// The microphone stream is never saved or sent to LiveKit.
abstract interface class AudioDeviceCheckService {
  Future<Stream<double>> startMicrophone({
    String? deviceId,
    String? deviceLabel,
  });
  Future<void> stopMicrophone();
  Future<void> playSpeaker({String? deviceId, String? deviceLabel});
  Future<void> dispose();
}

class AudioDeviceCheckFailure implements Exception {
  const AudioDeviceCheckFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class NativeAudioDeviceCheckService implements AudioDeviceCheckService {
  NativeAudioDeviceCheckService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _pcmSubscription;
  bool _recording = false;
  bool _disposed = false;

  @override
  Future<Stream<double>> startMicrophone({
    String? deviceId,
    String? deviceLabel,
  }) async {
    if (_disposed) {
      throw const AudioDeviceCheckFailure('Проверка микрофона недоступна.');
    }
    if (_recording) await stopMicrophone();
    if (!await _recorder.hasPermission()) {
      throw const AudioDeviceCheckFailure(
        'Не удалось проверить микрофон. Проверьте разрешение и выбранное устройство.',
      );
    }

    final devices = await _recorder.listInputDevices();
    final recorderDeviceId = await AndroidAudioDevices.recorderInputDeviceId(
      deviceId,
    );
    final selectedDevice = resolveInputDevice(
      selectedId: deviceId,
      selectedLabel: deviceLabel,
      available: devices,
      recorderDeviceId: recorderDeviceId,
    );

    try {
      // This starts an in-memory PCM stream only; amplitude samples remain
      // local and the PCM data itself is deliberately discarded.
      _recording = true;
      final pcm = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 48000,
          numChannels: 1,
          device: selectedDevice,
        ),
      );
      // Drain and discard PCM locally. The native stream must be consumed so
      // audio frames are not queued in the platform channel while measuring.
      _pcmSubscription = pcm.listen((_) {}, onError: (_) {});
      return _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .map((amplitude) => amplitudePercentFromDb(amplitude.current));
    } catch (_) {
      await _stopRecorderQuietly();
      rethrow;
    }
  }

  @override
  Future<void> stopMicrophone() async {
    if (!_recording) return;
    _recording = false;
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _recorder.stop();
  }

  @override
  Future<void> playSpeaker({String? deviceId, String? deviceLabel}) async {
    final soloud = SoLoud.instance;
    if (soloud.isInitialized) {
      throw const AudioDeviceCheckFailure(
        'Сейчас занят звуковой тест. Повторите попытку через мгновение.',
      );
    }
    if (AndroidAudioDevices.isAndroid &&
        AndroidAudioDevices.isNativeOutputRoute(deviceId)) {
      final selected = await AndroidAudioDevices.selectNativeOutput(deviceId!);
      if (!selected) {
        throw const AudioDeviceCheckFailure(
          'Не удалось выбрать аудиовыход для проверки. Проверьте его подключение и повторите попытку.',
        );
      }
    }

    final outputDevice = resolvePlaybackDevice(
      selectedId: deviceId,
      selectedLabel: deviceLabel,
      available: soloud.listPlaybackDevices(),
    );
    AudioSource? source;
    SoundHandle? handle;
    var initializedHere = false;
    final release = SoundEngineLease.acquire();
    if (release == null) throw const AudioDeviceCheckFailure('Сейчас занят звуковой выход. Повторите проверку через мгновение.');
    try {
      await soloud.init(device: outputDevice);
      initializedHere = true;
      source = await soloud.loadWaveform(WaveForm.sin, false, 1, 0);
      soloud.setWaveformFreq(source, 440);
      handle = soloud.play(source, volume: 0.12);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } catch (_) {
      throw const AudioDeviceCheckFailure(
        'Не удалось воспроизвести сигнал. Проверьте выбранный динамик и его подключение.',
      );
    } finally {
      if (handle != null && initializedHere && soloud.isInitialized) {
        try {
          await soloud.stop(handle);
        } catch (_) {}
      }
      if (source != null && initializedHere && soloud.isInitialized) {
        try {
          await soloud.disposeSource(source);
        } catch (_) {}
      }
      if (initializedHere && soloud.isInitialized) {
        try {
          await soloud.deinitAsync();
        } catch (_) {}
      }
      release();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stopRecorderQuietly();
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _recorder.dispose();
  }

  Future<void> _stopRecorderQuietly() async {
    if (!_recording) return;
    _recording = false;
    try {
      await _pcmSubscription?.cancel();
    } catch (_) {}
    _pcmSubscription = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }
}

InputDevice? resolveInputDevice({
  required String? selectedId,
  required String? selectedLabel,
  required List<InputDevice> available,
  String? recorderDeviceId,
}) {
  final mappedId = recorderDeviceId?.trim();
  if (mappedId != null && mappedId.isNotEmpty) {
    for (final device in available) {
      if (device.id == mappedId) return device;
    }
  }
  final id = selectedId?.trim();
  if (id == null || id.isEmpty || id == 'default') return null;
  for (final device in available) {
    if (device.id == id) return device;
  }
  final label = _normalizeDeviceLabel(selectedLabel);
  if (label.isNotEmpty) {
    for (final device in available) {
      if (_normalizeDeviceLabel(device.label) == label) return device;
    }
  }
  throw const AudioDeviceCheckFailure(
    'Не удалось найти выбранный микрофон для локальной проверки. Обновите список устройств.',
  );
}

PlaybackDevice? resolvePlaybackDevice({
  required String? selectedId,
  required String? selectedLabel,
  required List<PlaybackDevice> available,
}) {
  final id = selectedId?.trim();
  if (id == null || id.isEmpty || id == 'default') {
    for (final device in available) {
      if (device.isDefault) return device;
    }
    return null;
  }
  // Android communication outputs use AudioManager routes and are not
  // represented by SoLoud's integer device IDs. The app selects the route
  // before this local check, so SoLoud must use the current system route.
  if (AndroidAudioDevices.isNativeOutputRoute(id)) return null;
  final parsedId = int.tryParse(id);
  if (parsedId != null) {
    for (final device in available) {
      if (device.id == parsedId) return device;
    }
  }
  final label = _normalizeDeviceLabel(selectedLabel);
  if (label.isNotEmpty) {
    for (final device in available) {
      if (_normalizeDeviceLabel(device.name) == label) return device;
    }
  }
  throw const AudioDeviceCheckFailure(
    'Не удалось найти выбранный динамик для локальной проверки. Обновите список устройств.',
  );
}

double amplitudePercentFromDb(double db) {
  if (!db.isFinite || db <= -100) return 0;
  return math.pow(10, db / 20).clamp(0, 1).toDouble();
}

String _normalizeDeviceLabel(String? label) =>
    label?.trim().toLowerCase().replaceFirst(RegExp(r'\s*\([^)]*\)$'), '') ??
    '';
