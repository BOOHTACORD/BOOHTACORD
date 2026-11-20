import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class VoicePlaybackForegroundSession {
  VoicePlaybackForegroundSession({
    bool? android,
    Future<bool> Function(String)? invoke,
  }) : _android = android ?? Platform.isAndroid,
       _invoke =
           invoke ??
           ((method) async =>
               await channel.invokeMethod<bool>(method) ?? false) {
    if (_android && invoke == null) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'stopped' && !_disposed) {
          _generation++;
          active = false;
          onStopped?.call();
        }
      });
      _ownsHandler = true;
    }
  }

  static const channel = MethodChannel('boohtacord/voice_playback');
  final bool _android;
  bool get isAndroid => _android;
  final Future<bool> Function(String) _invoke;
  bool active = false;
  bool _disposed = false;
  bool _ownsHandler = false;
  int _generation = 0;
  void Function()? onStopped;

  Future<bool> canStart() async {
    if (_disposed) return false;
    if (!_android) return true;
    try {
      return await _invoke('canStart').timeout(const Duration(seconds: 2));
    } catch (_) {
      return false;
    }
  }

  Future<bool> start() async {
    if (_disposed) return false;
    if (!_android) return true;
    final generation = _generation;
    try {
      final ready = await _invoke('start').timeout(const Duration(seconds: 5));
      if (_disposed || generation != _generation) return false;
      active = ready;
      if (!ready) await stop();
      return ready;
    } catch (_) {
      await stop();
      return false;
    }
  }

  Future<void> stop() async {
    _generation++;
    active = false;
    if (_android) {
      try {
        await _invoke('stop').timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    onStopped = null;
    await stop();
    if (_ownsHandler) {
      channel.setMethodCallHandler(null);
      _ownsHandler = false;
    }
  }
}
