import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

import 'android_audio_devices.dart';

part 'audio_device_check/devices.dart';
part 'audio_device_check/microphone.dart';
part 'audio_device_check/speaker.dart';

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
  Future<Stream<double>> startMicrophone({String? deviceId, String? deviceLabel}) =>
      this._startMicrophone(deviceId: deviceId, deviceLabel: deviceLabel);

  @override
  Future<void> stopMicrophone() => this._stopMicrophone();

  @override
  Future<void> playSpeaker({String? deviceId, String? deviceLabel}) =>
      this._playSpeaker(deviceId: deviceId, deviceLabel: deviceLabel);

  @override
  Future<void> dispose() => this._disposeAudioCheck();
}
