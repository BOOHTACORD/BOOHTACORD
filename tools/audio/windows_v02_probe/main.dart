import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../windows_client_probe/loopback.dart';

const channel = MethodChannel('FlutterWebRTC.Method');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(home: Scaffold(body: Text('Local audio diagnostics'))),
  );
  final result = <String, Object?>{};
  final loopback = LocalAudioLoopback();
  MediaStream? stream;
  try {
    final marker = File(
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}rnnoise-v02-research-only.txt',
    );
    if (!await marker.exists()) throw StateError('research-marker-missing');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await channel.invokeMethod<Object?>('setNoiseSuppressionEngine', {
      'engine': 'rnnoise',
    });
    stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': false,
        'autoGainControl': false,
      },
      'video': false,
    });
    if (stream.getAudioTracks().length != 1)
      throw StateError('audio-track-count');
    await loopback.connect(stream);
    await Future<void>.delayed(const Duration(seconds: 8));
    final counters = await loopback.counters();
    final state = await channel.invokeMapMethod<String, dynamic>(
      'getNoiseSuppressionState',
    );
    result['remoteAudioTrack'] = loopback.receivedTrack;
    result.addAll(counters);
    result['capture'] = state;
    result['success'] =
        loopback.receivedTrack &&
        counters['receivedPackets']! > 0 &&
        state?['effectiveEngine'] == 'rnnoise' &&
        (state?['processedFrames'] as int? ?? 0) > 0 &&
        (state?['fallbackFrames'] as int? ?? 0) == 0;
  } catch (e) {
    result['errorType'] = e.runtimeType.toString();
    result['success'] = false;
  } finally {
    try {
      await loopback.close();
    } catch (_) {}
    for (final track in stream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await stream?.dispose();
    try {
      await channel.invokeMethod<Object?>('setNoiseSuppressionEngine', {
        'engine': 'browser',
      });
    } catch (_) {}
    final path = Platform.environment['BOOHTA_AUDIO_PROBE_RESULT'];
    if (path != null && path.isNotEmpty)
      await File(path).writeAsString(jsonEncode(result));
    exit(result['success'] == true ? 0 : 1);
  }
}
