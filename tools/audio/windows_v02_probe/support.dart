import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

Future<void> requireResearchMarker() async {
  final directory = File(Platform.resolvedExecutable).parent.path;
  if (!await File(
    '$directory${Platform.pathSeparator}rnnoise-v02-research-only.txt',
  ).exists()) {
    throw StateError('research-marker-missing');
  }
}

Future<Map<String, dynamic>> waitForEngine(
  MethodChannel channel,
  String engine,
  int previous,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(deadline)) {
    final state = await channel.invokeMapMethod<String, dynamic>(
      'getNoiseSuppressionState',
    );
    if (state?['effectiveEngine'] == engine &&
        (state?['processedFrames'] as int? ?? 0) > previous)
      return state!;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('engine-not-active');
}

Future<void> closeRooms(lk.Room sender, lk.Room receiver) async {
  try {
    await sender.localParticipant?.setMicrophoneEnabled(false);
  } catch (_) {}
  try {
    await sender.disconnect();
  } catch (_) {}
  try {
    await receiver.disconnect();
  } catch (_) {}
}

Future<Never> finishOutcome(
  MethodChannel channel,
  Map<String, Object?> result,
) async {
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
