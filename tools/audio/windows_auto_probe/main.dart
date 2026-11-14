import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'phase.dart';
import 'livekit_phase.dart';
import 'monitor.dart';

// Local research only. No recordings, SDP, tokens or device IDs are retained.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Text('Local Auto audio diagnostics')),
    ),
  );
  final result = <String, Object?>{};
  try {
    final root = File(Platform.resolvedExecutable).parent.path;
    if (!const bool.fromEnvironment('BOOHTA_AUTO_PROBE') ||
        const String.fromEnvironment('BOOHTA_RESEARCH_AUTO_ENGINE') != '' ||
        !await File(
          '$root${Platform.pathSeparator}rnnoise-v02-research-only.txt',
        ).exists()) {
      throw StateError('isolated-research-build-required');
    }
    final phases = <Map<String, Object?>>[];
    final seconds = probeSeconds(
      Platform.environment['BOOHTA_AUTO_PROBE_SECONDS'],
    );
    if (seconds > 6 &&
        (kDebugMode ||
            !Platform.environment.containsKey('BOOHTA_PROBE_SENDER_TOKEN'))) {
      throw StateError('optimized-local-sfu-required-for-endurance');
    }
    result['phases'] = phases;
    result['buildMode'] = kDebugMode
        ? 'debug'
        : kProfileMode
        ? 'profile'
        : 'release';
    final candidates = kDebugMode
        ? [false, true]
        : [const bool.fromEnvironment('BOOHTA_EXPERIMENTAL_DEEPFILTER')];
    for (final deepfilter in candidates) {
      result['stage'] = deepfilter ? 'auto-deepfilter' : 'auto-rnnoise';
      phases.add(
        await (Platform.environment.containsKey('BOOHTA_PROBE_SENDER_TOKEN')
            ? runAutoLivekitPhase(deepfilter, seconds: seconds)
            : runAutoPhase(deepfilter)),
      );
    }
    result['success'] = phases.every((phase) => phase['success'] == true);
  } catch (error) {
    result['errorType'] = error.runtimeType.toString();
    result['success'] = false;
  }
  final path = Platform.environment['BOOHTA_AUDIO_PROBE_RESULT'];
  if (path == null || await File(path).exists()) exit(2);
  await File(path).create(exclusive: true);
  await File(path).writeAsString(jsonEncode(result));
  exit(result['success'] == true ? 0 : 1);
}
