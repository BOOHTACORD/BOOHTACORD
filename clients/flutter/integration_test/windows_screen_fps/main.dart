import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:window_manager/window_manager.dart';

import 'profile.dart';
import 'scene.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sceneOnly = Platform.environment['BOOHTACORD_FPS_SCENE_ONLY'] == '1';
  final screen = Platform.environment['BOOHTACORD_FPS_SOURCE_SCREEN'] == '1';
  await windowManager.ensureInitialized();
  await windowManager.setTitle(
    sceneOnly ? 'BOOHTACORD FPS PROBE' : 'BOOHTACORD FPS CONTROLLER',
  );
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: Size(1000, 720)),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  if (sceneOnly && screen) await windowManager.setFullScreen(true);
  runApp(const FpsScene());
  await windowManager.setAlwaysOnTop(sceneOnly);
  if (sceneOnly) return;
  await Future<void>.delayed(const Duration(seconds: 2));
  final output = Platform.environment['BOOHTACORD_FPS_PROBE_OUTPUT'];
  if (output == null) throw StateError('Explicit QA result path is required');
  await File(output).writeAsString(jsonEncode({'status': 'starting'}));
  final results = <Map<String, dynamic>>[];
  try {
    final sources = await rtc.desktopCapturer.getSources(
      types: [screen ? rtc.SourceType.Screen : rtc.SourceType.Window],
    );
    final source = screen
        ? sources.first
        : sources.singleWhere((s) => s.name.contains('BOOHTACORD FPS PROBE'));
    Future<void> report(Map<String, dynamic> sample) async {
      results.add({...sample, 'source_type': screen ? 'screen' : 'window'});
      await File(output)
          .writeAsString(jsonEncode({'status': 'running', 'samples': results}));
    }

    final url = Platform.environment['BOOHTACORD_FPS_SFU_URL'];
    if (url != null) {
      await probeSfuSequence(source, url, report);
    } else {
      for (final fps in [15, 30, 60]) {
        await report(await probeProfile(source, fps));
      }
    }

    await File(output)
        .writeAsString(jsonEncode({'status': 'complete', 'samples': results}));
  } catch (e, stack) {
    final reason = e.toString().replaceAll(
      RegExp(r'[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'),
      '<redacted-token>',
    );
    await File(output).writeAsString(
      jsonEncode({
        'status': 'error',
        'error_type': e.runtimeType.toString(),
        'reason': reason.substring(0, reason.length.clamp(0, 300)),
        'stack': stack.toString().split('\n').take(8).toList(),
        'samples': results,
      }),
    );
  }
  exit(0);
}
