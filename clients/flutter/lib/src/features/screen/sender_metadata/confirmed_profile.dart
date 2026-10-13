import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import 'validation.dart';

Map<String, Object?>? confirmedScreenProfile(
  Map<String, Object?> capture,
  List<rtc.RTCRtpEncoding> encodings, {
  String? negotiatedCodec,
}) {
  if (capture['schema_version'] != 1 ||
      capture['status'] != 'active' ||
      capture['config_confirmed'] != true ||
      encodings.isEmpty ||
      encodings.length > 2) {
    return null;
  }
  final width = capture['actual_width'], height = capture['actual_height'];
  if (!validWhole(width, 2) || !validWhole(height, 2)) return null;
  final layers = <Map<String, Object?>>[];
  for (final encoding in encodings) {
    final scale = encoding.scaleResolutionDownBy;
    if (scale == null ||
        !scale.isFinite ||
        scale < 1 ||
        encoding.maxFramerate == null ||
        encoding.maxBitrate == null) {
      return null;
    }
    // Derived encoding limits, never a measurement of encoded or presented FPS.
    final layer = <String, Object?>{
      'rid': encoding.rid,
      'width': ((width as int) / scale / 2).floor() * 2,
      'height': ((height as int) / scale / 2).floor() * 2,
      'max_fps': encoding.maxFramerate,
      'max_bitrate_bps': encoding.maxBitrate,
      'scale_down_by': scale,
      'active': encoding.active,
    };
    if (!validLayer(layer)) return null;
    layers.add(layer);
  }
  final profile = <String, Object?>{
    'capture': {
      'max_width': capture['configured_width'],
      'max_height': capture['configured_height'],
      'max_fps': capture['configured_max_fps'],
    },
    'encoding': {'codec': negotiatedCodec, 'layers': layers},
  };
  return validEffectiveProfile(profile) ? profile : null;
}
