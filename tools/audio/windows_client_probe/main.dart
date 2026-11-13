import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'loopback.dart';

const channel = MethodChannel('FlutterWebRTC.Method');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Text('Audio diagnostics'))));
  final result = <String, Object?>{};
  final loopback = LocalAudioLoopback();
  MediaStream? stream;
  try {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    var state = await channel.invokeMapMethod<String, dynamic>(
      'setNoiseSuppressionEngine',
      {'engine': 'deepfilter'},
    );
    result['set'] = state;
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (state?['failureReason'] == 'awaiting-model' &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      state = await channel.invokeMapMethod<String, dynamic>(
        'getNoiseSuppressionState',
      );
    }
    result['prepared'] = state;
    if (state?['failureReason'] != 'awaiting-audio')
      throw StateError('model-not-ready');
    stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': false,
        'autoGainControl': false,
      },
      'video': false,
    });
    result['trackCount'] = stream.getAudioTracks().length;
    if (stream.getAudioTracks().length != 1)
      throw StateError('audio-track-count');
    await loopback.connect(stream);
    final transitions = <Map<String, Object?>>[];
    String? lastReason;
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final snapshot = await channel.invokeMapMethod<String, dynamic>(
        'getNoiseSuppressionState',
      );
      final reason = snapshot?['failureReason'] as String? ?? '';
      if (reason != lastReason) {
        transitions.add({
          'reason': reason,
          'fallbackFrames': snapshot?['fallbackFrames'],
          'processedFrames': snapshot?['processedFrames'],
        });
        lastReason = reason;
      }
    }
    result['transitions'] = transitions;
    await Future<void>.delayed(const Duration(seconds: 7));
    result['remoteAudioTrack'] = loopback.receivedTrack;
    final counters = await loopback.counters();
    result.addAll(counters);
    state = await channel.invokeMapMethod<String, dynamic>(
      'getNoiseSuppressionState',
    );
    result['capture'] = state;
    result['success'] =
        loopback.receivedTrack &&
        counters['receivedPackets']! > 0 &&
        state?['effectiveEngine'] == 'deepfilter' &&
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
