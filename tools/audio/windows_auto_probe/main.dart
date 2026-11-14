import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'phase.dart';

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
    if (!kDebugMode ||
        const String.fromEnvironment('BOOHTA_RESEARCH_AUTO_ENGINE') != '' ||
        !await File(
          '$root${Platform.pathSeparator}rnnoise-v02-research-only.txt',
        ).exists()) {
      throw StateError('isolated-debug-research-build-required');
    }
    final phases = <Map<String, Object?>>[];
    result['phases'] = phases;
    for (final deepfilter in [false, true]) {
      result['stage'] = deepfilter ? 'auto-deepfilter' : 'auto-rnnoise';
      phases.add(await runAutoPhase(deepfilter));
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
