// QA-only private-build adapter. Not imported by production application source.
import 'dart:async' as async;
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:boohtacord_desktop/src/features/screen/capture/driver.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/dimensions.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/native_readback.dart';
import 'package:boohtacord_desktop/src/features/screen/rollout/policy.dart';
import 'package:boohtacord_desktop/src/features/screen/rollout/publish_plan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

// The host validates the canonical, mode-0600, marked source file before
// preparing this bounded envelope. This transports evidence, not privileges.
Map<String, dynamic> qaReadCodecCapabilitiesEnvironment(
  Map<String, String> environment,
) {
  Never reject() => throw StateError('Invalid controlled capability envelope');
  final encoded = environment['QA_NATIVE_CODEC_CAPS_B64'];
  final digest = environment['QA_NATIVE_CODEC_CAPS_SHA256'];
  if (environment['QA_NATIVE_CODEC_PHASE_ADMITTED'] != '1' ||
      encoded == null ||
      encoded.length > 87384 ||
      digest == null ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
    reject();
  }
  dynamic data;
  try {
    final bytes = base64Decode(encoded);
    if (bytes.length > 65536 || sha256.convert(bytes).toString() != digest) {
      reject();
    }
    data = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    reject();
  }
  bool exact(Map value, Set<String> keys) =>
      value.length == keys.length && value.keys.every(keys.contains);
  if (data is! Map ||
      !exact(data, {
        'schema_version',
        'measured',
        'receiver_capabilities',
        'ownership_proof',
      }) ||
      data['schema_version'] != 1 ||
      data['measured'] != true) {
    reject();
  }
  final proof = data['ownership_proof'];
  if (proof is! Map ||
      !exact(proof, {'kind', 'marker_sha256', 'source_caps_sha256'}) ||
      proof['kind'] != 'marked_physical_mac_qa' ||
      proof['marker_sha256'] !=
          sha256.convert(utf8.encode('owned physical Mac QA\n')).toString() ||
      proof['source_caps_sha256'] is! String ||
      !RegExp(r'^[0-9a-f]{64}$')
          .hasMatch(proof['source_caps_sha256'] as String)) {
    reject();
  }
  final receivers = data['receiver_capabilities'];
  if (receivers is! List || receivers.isEmpty || receivers.length > 8) reject();
  for (final rows in receivers) {
    if (rows is! List || rows.isEmpty || rows.length > 32) reject();
    for (final row in rows) {
      if (row is! Map ||
          !exact(row, {'mimeType', 'clockRate', 'sdpFmtpLine'}) ||
          !{
            'video/vp8',
            'video/h264',
          }.contains('${row['mimeType']}'.toLowerCase()) ||
          row['clockRate'] != 90000 ||
          row['sdpFmtpLine'] is! String) {
        reject();
      }
      final fmtp = row['sdpFmtpLine'] as String;
      if (fmtp.length > 256) reject();
      final seen = <String>{};
      for (final part in fmtp.split(';')) {
        if (part.trim().isEmpty) continue;
        final token = part.trim().toLowerCase();
        if (!RegExp(
              r'^(profile-level-id=[0-9a-f]{6}|packetization-mode=[01]|level-asymmetry-allowed=[01])$',
            ).hasMatch(token) ||
            !seen.add(token.split('=').first)) {
          reject();
        }
      }
      if ('${row['mimeType']}'.toLowerCase() == 'video/vp8' &&
          fmtp.isNotEmpty) {
        reject();
      }
    }
  }
  return Map<String, dynamic>.from(data);
}

Map<String, Object?> qaCodecAdmissionDiagnostic({
  required String phase,
  String? reason,
  String? errorClass,
  int? osErrorCode,
  bool? roomConnected,
  List<String>? sfuCodecs,
  int? senderCodecs,
  int? viewerEndpoints,
}) {
  const phases = {
    'start',
    'caps_read',
    'sender_caps',
    'sfu_observed',
    'admitted',
    'rejected',
    'publish',
  };
  const reasons = {
    'observed',
    'admitted',
    'phase_not_admitted',
    'caps_missing',
    'invalid_caps',
    'file_access',
    'room_unavailable',
    'room_not_connected',
    'codec_not_compatible',
    'connected_SFU_no_explicit_restriction',
    'sfu_allowlist',
    'publish_failure',
    'readback_unavailable',
  };
  return {
    'schema_version': 1,
    'event': 'admission',
    'phase': phases.contains(phase) ? phase : 'rejected',
    'reason': reasons.contains(reason) ? reason : 'unknown',
    'error_class':
        {
          'StateError',
          'FileSystemException',
          'FormatException',
          'TimeoutException',
        }.contains(errorClass)
        ? errorClass
        : null,
    'os_error_code': {1, 2, 13}.contains(osErrorCode) ? osErrorCode : null,
    'room_connected': roomConnected,
    'sfu_snapshot': sfuCodecs == null
        ? 'unknown'
        : sfuCodecs.isEmpty
        ? 'empty'
        : 'explicit',
    'sfu_known_codecs': sfuCodecs
        ?.map((v) => v.toLowerCase().replaceFirst('video/', ''))
        .where({'vp8', 'h264'}.contains)
        .toSet()
        .toList(),
    'sender_codec_count':
        senderCodecs != null && senderCodecs >= 0 && senderCodecs <= 64
        ? senderCodecs
        : null,
    'viewer_endpoint_count':
        viewerEndpoints != null && viewerEndpoints >= 0 && viewerEndpoints <= 8
        ? viewerEndpoints
        : null,
    'hardware_proven': false,
  };
}

void _codecDiagnostic(Map<String, Object?> value) {
  // Fixed prefix and allowlisted projection; never exception.toString()/paths.
  stdout.writeln('QA_CODEC_DIAGNOSTIC ${jsonEncode(value)}');
}

Set<String> _profiles(List<dynamic>? rows, String codec) {
  if (rows == null) throw StateError('Unknown codec capability snapshot');
  final result = <String>{};
  for (final row in rows) {
    if (row is! Map ||
        '${row['mimeType']}'.toLowerCase() != 'video/$codec' ||
        row['clockRate'] != 90000) {
      continue;
    }
    if (codec == 'vp8') {
      result.add('vp8');
      continue;
    }
    final fmtp = row['sdpFmtpLine'];
    if (fmtp is! String) continue;
    final parameters = <String, String>{};
    var invalid = false;
    for (final part in fmtp.split(';')) {
      if (part.trim().isEmpty) continue;
      final at = part.indexOf('=');
      if (at < 1) {
        invalid = true;
        break;
      }
      final key = part.substring(0, at).trim().toLowerCase();
      if (parameters.containsKey(key)) {
        invalid = true;
        break;
      }
      parameters[key] = part.substring(at + 1).trim().toLowerCase();
    }
    final profile = parameters['profile-level-id'] ?? '';
    final level = profile.length == 6
        ? int.tryParse(profile.substring(4), radix: 16)
        : null;
    final asymmetry = parameters['level-asymmetry-allowed'] ?? '0';
    const levels = {
      10,
      11,
      12,
      13,
      20,
      21,
      22,
      30,
      31,
      32,
      40,
      41,
      42,
      50,
      51,
      52,
    };
    if (!invalid &&
        profile.startsWith('42e0') &&
        levels.contains(level) &&
        parameters['packetization-mode'] == '1' &&
        {'0', '1'}.contains(asymmetry)) {
      result.add('$profile:1');
    }
  }
  return result;
}

String qaSharedCodecProfile(
  String codec,
  List<dynamic>? sender,
  List<dynamic> receivers,
  List<String>? sfu, {
  bool sfuNoExplicitRestriction = false,
}) {
  if (!{'vp8', 'h264'}.contains(codec) ||
      receivers.isEmpty ||
      sfu == null ||
      !(sfu.isEmpty && sfuNoExplicitRestriction) &&
          !sfu
              .map((v) => v.toLowerCase().replaceFirst('video/', ''))
              .contains(codec)) {
    throw StateError('Controlled codec unavailable');
  }
  final endpoints = [_profiles(sender, codec)];
  for (final receiver in receivers) {
    if (receiver is! List) throw StateError('Unknown receiver capabilities');
    endpoints.add(_profiles(receiver, codec));
  }
  if (endpoints.any((profiles) => profiles.isEmpty)) {
    throw StateError('No compatible controlled codec profile');
  }
  if (codec == 'vp8') return 'vp8';
  // RFC6184 level is distinct from profile compatibility. Record the common
  // maximum level conservatively; actual negotiated FMTP still requires readback.
  final level = endpoints
      .map(
        (profiles) => profiles
            .map((p) => int.parse(p.substring(4, 6), radix: 16))
            .reduce((a, b) => a > b ? a : b),
      )
      .reduce((a, b) => a < b ? a : b);
  return '42e0${level.toRadixString(16).padLeft(2, '0')}:1';
}

bool qaActualFmtpAccepted(String admittedProfile, String? fmtp) {
  if (!RegExp(r'^42e0[0-9a-f]{2}:1$').hasMatch(admittedProfile) ||
      fmtp == null) {
    return false;
  }
  final actual = _profiles([
    {'mimeType': 'video/h264', 'clockRate': 90000, 'sdpFmtpLine': fmtp},
  ], 'h264');
  final admittedLevel = int.parse(admittedProfile.substring(4, 6), radix: 16);
  return actual.length == 1 &&
      int.parse(actual.single.substring(4, 6), radix: 16) <= admittedLevel;
}

Future<T> qaReadCodecWithinDeadline<T>(
  Future<T> Function() read,
  DateTime deadline,
) {
  final remaining = deadline.difference(DateTime.now());
  if (remaining <= Duration.zero) {
    return Future<T>.error(
      async.TimeoutException('Codec verification deadline elapsed'),
    );
  }
  // Timeout detaches the verifier from a late native completion. No later
  // caller continuation can emit a confirmed receipt for the timed-out attempt.
  return read().timeout(remaining);
}

String? qaActualCodecName(String? value) {
  final codec = value?.toLowerCase();
  return {'vp8', 'h264'}.contains(codec) ? codec : null;
}

Map<String, Object?> qaCodecReadbackProjection(
  NativeScreenProfileReadback? value,
) {
  num? bounded(Object? raw, num maximum) =>
      raw is num && raw.isFinite && raw >= 0 && raw <= maximum ? raw : null;
  final fmtp = value?.codecFmtp
      ?.split(';')
      .map((p) => p.trim())
      .where(
        (p) => RegExp(
          r'^(profile-level-id|packetization-mode|level-asymmetry-allowed)=[0-9a-f]{1,6}$',
          caseSensitive: false,
        ).hasMatch(p),
      )
      .take(3)
      .join(';');
  return {
    'schema_version': 1,
    'method': 'fresh_pc_getSenders_and_actual_outbound_codecId',
    'actual_codec': qaActualCodecName(value?.codec),
    'codec_fmtp': fmtp == null || fmtp.isEmpty ? null : fmtp,
    'capture': {
      for (final key in [
        'actual_width',
        'actual_height',
        'configured_width',
        'configured_height',
        'configured_max_fps',
      ])
        key: bounded(value?.capture[key], 16384),
    },
    'encodings': [
      for (final encoding in value?.encodings.take(2) ?? <rtc.RTCRtpEncoding>[])
        {
          'max_fps': bounded(encoding.maxFramerate, 240),
          'max_bitrate_bps': bounded(encoding.maxBitrate, 100000000),
          'scale_down_by': bounded(encoding.scaleResolutionDownBy, 64),
          'active': encoding.active,
        },
    ],
    'hardware_proven': false,
  };
}

Future<void> qaWriteCodecReadbackReceipt(
  File capsFile,
  NativeScreenProfileReadback? readback, {
  String? requested,
  String? admittedProfile,
  String status = 'observed',
}) async {
  final file = capsFile.absolute;
  final resolved = File(await file.resolveSymbolicLinks());
  final marker = File('${file.parent.path}/.qa98325-owned');
  if (file.uri.pathSegments.last != 'codec-receivers-private.json' ||
      resolved.parent.path != file.parent.path ||
      !marker.existsSync() ||
      marker.readAsStringSync() != 'owned physical Mac QA\n') {
    throw StateError('Owned negotiation receipt directory required');
  }
  final folder = await file.parent.createTemp('qa-codec-receipt-');
  try {
    final pending = File('${folder.path}/receipt.json');
    await pending.writeAsString(
      jsonEncode({
        ...qaCodecReadbackProjection(readback),
        'requested_codec': qaActualCodecName(requested),
        'admitted_profile':
            admittedProfile != null &&
                RegExp(r'^(vp8|42e0[0-9a-f]{2}:1)$').hasMatch(admittedProfile)
            ? admittedProfile
            : null,
        'status':
            {
              'observed',
              'confirmed',
              'deferred',
              'mismatch',
              'unavailable',
            }.contains(status)
            ? status
            : 'unavailable',
      }),
    );
    await pending.rename('${file.parent.path}/codec-negotiation-private.json');
  } finally {
    await folder.delete(recursive: true);
  }
}

ScreenShareCaptureOptions qaCaptureDiagnosticsOptions(
  ScreenShareCaptureOptions options,
  String? value,
) {
  if (value == null) return options;
  if (!{'0', '1'}.contains(value)) {
    throw StateError('Explicit diagnostics value must be 0 or 1');
  }
  return options.copyWith(captureDiagnosticsEnabled: value == '1');
}

class QaCodecScreenDriver extends NativeScreenShareDriver {
  QaCodecScreenDriver({required this.readRoom});
  final Room? Function() readRoom;
  String? _admitted;
  String? _admittedProfile;
  File? _capsFile;
  bool _environmentCaps = false;
  bool _readbackObserved = false;
  String? _capsDigest;
  NativeScreenProfileReadback? _lastReadback;
  String? get requested => Platform.environment['QA_NATIVE_CODEC'];

  @override
  Future<LocalVideoTrack> capture(ScreenShareCaptureOptions options) {
    final value = Platform.environment['QA_NATIVE_CAPTURE_DIAGNOSTICS'];
    if (value != null && !Platform.isMacOS) {
      throw StateError('Native diagnostics experiment is Mac-only');
    }
    return super.capture(qaCaptureDiagnosticsOptions(options, value));
  }

  Future<void> _recordReadback(
    NativeScreenProfileReadback? readback, {
    String? requested,
    String? admittedProfile,
    String status = 'observed',
  }) async {
    if (_environmentCaps) {
      if (status != 'observed' || !_readbackObserved) {
        _codecDiagnostic({
          ...qaCodecReadbackProjection(readback),
          'event': 'readback',
          'requested_codec': qaActualCodecName(requested),
          'admitted_profile': admittedProfile,
          'status': status,
          'caps_payload_sha256': _capsDigest,
        });
        _readbackObserved = true;
      }
      return;
    }
    await qaWriteCodecReadbackReceipt(
      _capsFile!,
      readback,
      requested: requested,
      admittedProfile: admittedProfile,
      status: status,
    );
  }

  Future<void> _verifyActualCodec(
    Room room,
    LocalVideoTrack track,
    String codec,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(deadline)) {
      final readback = await qaReadCodecWithinDeadline(
        () => readNativeScreenProfile(room, track),
        deadline,
      );
      _lastReadback = readback;
      final actual = qaActualCodecName(readback?.codec);
      await _recordReadback(
        readback,
        requested: codec,
        admittedProfile: _admittedProfile,
      );
      if (readback?.codec != null && actual != codec) {
        await _recordReadback(
          readback,
          requested: codec,
          admittedProfile: _admittedProfile,
          status: 'mismatch',
        );
        throw StateError('Actual negotiated codec mismatch');
      }
      if (actual == codec) {
        if (codec == 'vp8') {
          await _recordReadback(
            readback,
            requested: codec,
            admittedProfile: _admittedProfile,
            status: 'confirmed',
          );
          return;
        }
        final fmtp = readback?.codecFmtp;
        if (qaActualFmtpAccepted(_admittedProfile ?? '', fmtp)) {
          await _recordReadback(
            readback,
            requested: codec,
            admittedProfile: _admittedProfile,
            status: 'confirmed',
          );
          return;
        }
        if (fmtp != null) {
          await _recordReadback(
            readback,
            requested: codec,
            admittedProfile: _admittedProfile,
            status: 'deferred',
          );
          throw StateError(
            'Negotiated H264 profile or level exceeds admitted cohort',
          );
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await _recordReadback(
      _lastReadback,
      requested: codec,
      admittedProfile: _admittedProfile,
      status: 'unavailable',
    );
    throw StateError('Actual negotiated codec/FMTP readback unavailable');
  }

  @override
  Future<bool> updateQuality(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
    bool Function() isCurrent,
  ) {
    if (requested != null) {
      throw StateError(
        'Fixed-profile codec experiment; quality changes require a fresh paired run',
      );
    }
    return super.updateQuality(room, track, quality, dimensions, isCurrent);
  }

  @override
  Future<void> prepare(bool Function() active) async {
    _admitted = null;
    _admittedProfile = null;
    _capsFile = null;
    _environmentCaps = false;
    _readbackObserved = false;
    _capsDigest = null;
    _lastReadback = null;
    await super.prepare(active);
    final codec = requested;
    if (codec == null || !active()) return;
    var phase = 'start';
    var reason = 'phase_not_admitted';
    try {
      if (!Platform.isMacOS ||
          Platform.environment['QA_NATIVE_CODEC_PHASE_ADMITTED'] != '1') {
        throw StateError('Codec A/B phase not admitted');
      }
      phase = 'caps_read';
      reason = 'invalid_caps';
      dynamic data;
      File? file;
      if (Platform.environment.containsKey('QA_NATIVE_CODEC_CAPS_B64')) {
        data = qaReadCodecCapabilitiesEnvironment(Platform.environment);
        _environmentCaps = true;
        _capsDigest = Platform.environment['QA_NATIVE_CODEC_CAPS_SHA256'];
      } else {
        final filename = Platform.environment['QA_NATIVE_CODEC_CAPS_FILE'];
        if (filename == null) {
          reason = 'caps_missing';
          throw StateError('Owned measured receiver capabilities required');
        }
        file = File(filename).absolute;
        reason = 'file_access';
        final resolved = File(await file.resolveSymbolicLinks());
        if (!file.path.endsWith('/codec-receivers-private.json') ||
            resolved.parent.path != file.parent.path ||
            !File('${file.parent.path}/.qa98325-owned').existsSync() ||
            File('${file.parent.path}/.qa98325-owned').readAsStringSync() !=
                'owned physical Mac QA\n') {
          throw StateError('Owned capability file required');
        }
        data = jsonDecode(await file.readAsString());
        if (data is! Map ||
            data['schema_version'] != 1 ||
            data['measured'] != true ||
            data['receiver_capabilities'] is! List) {
          reason = 'invalid_caps';
          throw StateError('Measured versioned capabilities required');
        }
      }
      phase = 'sender_caps';
      reason = 'observed';
      final caps = await rtc.getRtpSenderCapabilities('video');
      final sender = caps.codecs
          ?.map(
            (c) => {
              'mimeType': c.mimeType,
              'clockRate': c.clockRate,
              'sdpFmtpLine': c.sdpFmtpLine,
            },
          )
          .toList();
      final room = readRoom();
      if (room == null) {
        reason = 'room_unavailable';
        throw StateError('Owned voice room unavailable');
      }
      final connected = room.connectionState == ConnectionState.connected;
      if (!connected) {
        reason = 'room_not_connected';
        throw StateError('Owned voice room not connected');
      }
      // SDK local.dart applies the server list only when non-empty. Explicit
      // opt-in records that source-bound semantic; null still means unknown.
      // ignore: invalid_use_of_internal_member
      final sfu = room.engine.enabledPublishCodecs?.map((c) => c.mime).toList();
      _codecDiagnostic(
        qaCodecAdmissionDiagnostic(
          phase: 'sfu_observed',
          reason: 'observed',
          roomConnected: connected,
          sfuCodecs: sfu,
          senderCodecs: sender?.length,
          viewerEndpoints: (data['receiver_capabilities'] as List).length,
        ),
      );
      final unrestricted =
          sfu != null &&
          sfu.isEmpty &&
          Platform.environment['QA_NATIVE_CODEC_SFU_EMPTY_ADMITTED'] == '1';
      phase = 'rejected';
      reason = 'codec_not_compatible';
      final profile = qaSharedCodecProfile(
        codec,
        sender,
        data['receiver_capabilities'] as List,
        sfu,
        sfuNoExplicitRestriction: unrestricted,
      );
      if (active()) {
        _admitted = codec;
        _admittedProfile = profile;
        _capsFile = file;
        _codecDiagnostic({
          ...qaCodecAdmissionDiagnostic(
            phase: 'admitted',
            reason: unrestricted
                ? 'connected_SFU_no_explicit_restriction'
                : 'sfu_allowlist',
            roomConnected: connected,
            sfuCodecs: sfu,
            senderCodecs: sender?.length,
            viewerEndpoints: (data['receiver_capabilities'] as List).length,
          ),
          'requested_codec': qaActualCodecName(codec),
          'admitted_profile': profile,
          'caps_payload_sha256': _capsDigest,
        });
      }
    } catch (error) {
      _codecDiagnostic(
        qaCodecAdmissionDiagnostic(
          phase: phase,
          reason: reason,
          errorClass: error.runtimeType.toString(),
          osErrorCode: error is FileSystemException
              ? error.osError?.errorCode
              : null,
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> publish(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
  ) async {
    final codec = requested;
    if (codec == null) {
      await super.publish(room, track, quality, dimensions);
      return;
    }
    if (_admitted != codec) {
      throw StateError('Controlled codec was not admitted before capture');
    }
    if (track.currentOptions is ScreenShareCaptureOptions &&
        (track.currentOptions as ScreenShareCaptureOptions)
            .captureScreenAudio) {
      throw StateError('Video-only codec experiment required');
    }
    final participant = room.localParticipant;
    if (participant == null) {
      throw StateError('Owned voice publication unavailable');
    }
    final options = nativeScreenPublishPlan(
      quality,
      const ScreenMediaRollout(boundedSimulcast: false),
      TargetPlatform.macOS,
      sourceDimensions: screenShareCaptureDimensions(track) ?? dimensions,
    ).copyWith(videoCodec: codec);
    await participant.publishVideoTrack(track, publishOptions: options);
    try {
      await _verifyActualCodec(room, track, codec);
    } on async.TimeoutException {
      await _recordReadback(
        _lastReadback,
        requested: codec,
        admittedProfile: _admittedProfile,
        status: 'unavailable',
      );
      _codecDiagnostic(
        qaCodecAdmissionDiagnostic(
          phase: 'publish',
          reason: 'readback_unavailable',
          errorClass: 'TimeoutException',
        ),
      );
      rethrow;
    }
  }
}
