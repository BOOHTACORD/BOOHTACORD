import 'dart:io';

import 'package:flutter/services.dart';

import 'utils.dart';

typedef CaptureSnapshotInvoker = Future<Object?> Function(
    String method, Map<String, Object?> arguments);

const unavailableCaptureSnapshot = <String, dynamic>{
  'schema_version': 1,
  'status': 'unavailable',
  'config_confirmed': false,
};

/// Queries bounded numeric diagnostics; it does not infer capture settings.
class CaptureSnapshotBridge {
  CaptureSnapshotBridge({bool? supported, CaptureSnapshotInvoker? invoke})
      : _supported = supported ?? Platform.isMacOS,
        _invoke = invoke ??
            ((method, arguments) =>
                WebRTC.invokeMethod<Object?, Object?>(method, arguments));

  final bool _supported;
  final CaptureSnapshotInvoker _invoke;

  Future<Map<String, dynamic>> read(String trackId) async {
    if (!_supported || trackId.isEmpty) return unavailableCaptureSnapshot;
    try {
      final value = await _invoke('mediaStreamTrackGetCaptureSnapshot',
          <String, Object?>{'trackId': trackId});
      if (value is! Map || value['schema_version'] != 1) {
        return unavailableCaptureSnapshot;
      }
      return Map<String, dynamic>.from(value);
    } on MissingPluginException {
      return unavailableCaptureSnapshot;
    } on PlatformException {
      return unavailableCaptureSnapshot;
    }
  }
}

Future<Map<String, dynamic>> mediaStreamTrackGetCaptureSnapshot(
        String trackId) =>
    CaptureSnapshotBridge().read(trackId);
