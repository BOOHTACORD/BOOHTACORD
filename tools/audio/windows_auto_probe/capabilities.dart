import 'package:flutter/services.dart';

Future<Map<String, Object?>> probeCapabilities() async {
  const channel = MethodChannel('FlutterWebRTC.Method');
  final raw = await channel.invokeMapMethod<String, dynamic>(
    'getNoiseSuppressionCapabilities',
  );
  return {
    for (final key in [
      'rnnoiseModelId',
      'rnnoisePreflightState',
      'rnnoisePreflightStage',
      'rnnoiseP95Us',
      'rnnoiseMaxUs',
      'deepfilterModelId',
    ])
      key: raw?[key],
  };
}
