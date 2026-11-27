import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class MicrophoneForegroundSession {
  MicrophoneForegroundSession({
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
          _starting = null;
          active = false;
          onStopped?.call();
        }
      });
      _ownsHandler = true;
    }
  }
  static const channel = MethodChannel('boohtacord/voice_microphone');
  final bool _android;
  final Future<bool> Function(String) _invoke;
  bool active = false, _disposed = false, _ownsHandler = false;
  int _generation = 0;
  Future<bool>? _starting;
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

  Future<bool> start() {
    if (_disposed) return Future.value(false);
    if (!_android) return Future.value(true);
    return _starting ??= _start(_generation);
  }

  Future<bool> _start(int generation) async {
    try {
      final ready = await _invoke('start').timeout(const Duration(seconds: 5));
      if (_disposed || generation != _generation) return false;
      active = ready;
      return ready;
    } catch (_) {
      if (!_disposed && generation == _generation) await stop();
      return false;
    } finally {
      if (generation == _generation) _starting = null;
    }
  }

  Future<void> stop() async {
    _generation++;
    _starting = null;
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
