import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../windows_auto_probe/phase.dart';

// Isolated diagnostic entrypoint; uses the ordinary CMake engine delivery.
// Microphone audio stays between local peers; no PCM or identifiers are saved.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Text('Production audio engine acceptance')),
    ),
  );
  final result = <String, Object?>{};
  try {
    final root = File(Platform.resolvedExecutable).parent;
    final marker = jsonDecode(
      await File('${root.path}/rnnoise-engine.json').readAsString(),
    );
    if (marker['modelId'] != 'rnnoise-release-v0.2' ||
        await File('${root.path}/rnnoise-v02-research-only.txt').exists()) {
      throw StateError('ordinary-production-engines-required');
    }
    final phases = <Map<String, Object?>>[];
    result['phases'] = phases;
    for (final deepfilter in [false, true]) {
      phases.add(await runAutoPhase(deepfilter, automatic: deepfilter));
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
