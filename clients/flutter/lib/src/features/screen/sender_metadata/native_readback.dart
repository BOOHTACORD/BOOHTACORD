import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

class NativeScreenProfileReadback {
  const NativeScreenProfileReadback(
    this.capture,
    this.encodings, {
    this.codec,
    this.codecFmtp,
  });
  final Map<String, Object?> capture;
  final List<rtc.RTCRtpEncoding> encodings;
  final String? codec, codecFmtp;
}

/// A newly returned sender contains native parameters, unlike track.sender's
/// cached parameters. Unsupported capture bridges remain pending.
Future<NativeScreenProfileReadback?> readNativeScreenProfile(
  Room room,
  LocalVideoTrack track, {
  bool includeCodecStats = true,
}) async {
  // Pinned LiveKit 2.13 adapter: request fresh native sender parameters here;
  // track.sender.parameters is a cache. Keep this read-only boundary isolated.
  // ignore: invalid_use_of_internal_member
  final pc = room.engine.publisher?.pc;
  final trackId = track.mediaStreamTrack.id;
  if (pc == null || trackId == null || trackId.isEmpty) return null;
  final senders = await pc.getSenders().timeout(const Duration(seconds: 1));
  rtc.RTCRtpSender? sender;
  for (final candidate in senders) {
    if (candidate.track?.id == trackId) sender = candidate;
  }
  if (sender == null) return null;
  final encodings = sender.parameters.encodings;
  if (encodings == null || encodings.isEmpty) return null;
  var capture = <String, Object?>{};
  try {
    final value = await rtc
        .mediaStreamTrackGetCaptureSnapshot(trackId)
        .timeout(const Duration(seconds: 1));
    capture = Map<String, Object?>.from(value);
  } catch (_) {
    // Missing bridge is unknown configuration, not a selected-profile fallback.
  }
  String? codec, fmtp;
  if (includeCodecStats) {
    try {
      final reports = await sender.getStats().timeout(
        const Duration(seconds: 1),
      );
      final used = usedScreenCodec(reports);
      codec = used?.$1;
      fmtp =
          used?.$2 ??
          usedScreenCodecFmtp(reports, sender.parameters.codecs ?? []);
    } catch (_) {}
  }
  return NativeScreenProfileReadback(
    capture,
    encodings,
    codec: codec,
    codecFmtp: fmtp,
  );
}

(String, String?)? usedScreenCodec(List<rtc.StatsReport> reports) {
  final ids = reports
      .where(
        (row) =>
            row.type == 'outbound-rtp' &&
            (row.values['kind'] ?? row.values['mediaType']) == 'video',
      )
      .map((row) => row.values['codecId'])
      .whereType<String>()
      .toSet();
  if (ids.length != 1) return null;
  for (final row in reports) {
    if (row.type != 'codec' || row.id != ids.single) continue;
    final mime = row.values['mimeType'];
    if (mime is! String || !mime.startsWith('video/')) return null;
    final name = mime.substring(6);
    if (name.isEmpty || name.length > 32) return null;
    final fmtp = row.values['sdpFmtpLine'];
    return (name, fmtp is String && fmtp.length <= 1024 ? fmtp : null);
  }
  return null;
}

String? usedScreenCodecFmtp(
  List<rtc.StatsReport> reports,
  List<rtc.RTCRTPCodec> freshCodecs,
) {
  final used = usedScreenCodec(reports);
  if (used == null) return null;
  if (used.$2 != null) return used.$2;
  final ids = reports
      .where(
        (row) =>
            row.type == 'outbound-rtp' &&
            (row.values['kind'] ?? row.values['mediaType']) == 'video',
      )
      .map((row) => row.values['codecId'])
      .whereType<String>()
      .toSet();
  final rows = reports.where(
    (row) => row.type == 'codec' && ids.contains(row.id),
  );
  if (rows.length != 1) return null;
  final payload = rows.single.values['payloadType'];
  if (payload is! num) return null;
  final matches = freshCodecs.where(
    (codec) =>
        codec.payloadType == payload &&
        codec.kind == 'video' &&
        codec.name?.toLowerCase() == used.$1.toLowerCase(),
  );
  if (matches.length != 1) return null;
  final parameters = matches.single.parameters;
  if (parameters == null) return null;
  const allowed = [
    'level-asymmetry-allowed',
    'packetization-mode',
    'profile-level-id',
  ];
  final parts = <String>[];
  for (final key in allowed) {
    final value = parameters[key]?.toString();
    if (value == null) continue;
    if (!RegExp(r'^[a-zA-Z0-9]{1,32}$').hasMatch(value)) return null;
    parts.add('$key=$value');
  }
  return parts.isEmpty ? null : parts.join(';');
}
