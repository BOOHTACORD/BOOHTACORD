import 'dart:async' as async;
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:boohtacord_desktop/src/features/screen/sender_metadata/native_readback.dart';

import '../../../../../tools/qa/macos_sender/codec_driver.dart';

List<Map<String, Object>> caps(String codec, [String fmtp = '']) => [
  {'mimeType': 'video/$codec', 'clockRate': 90000, 'sdpFmtpLine': fmtp},
];

Map<String, Object?> environmentPayload() => {
  'schema_version': 1,
  'measured': true,
  'receiver_capabilities': [
    [
      {'mimeType': 'video/VP8', 'clockRate': 90000, 'sdpFmtpLine': ''},
    ],
  ],
  'ownership_proof': {
    'kind': 'marked_physical_mac_qa',
    'marker_sha256': sha256
        .convert(utf8.encode('owned physical Mac QA\n'))
        .toString(),
    'source_caps_sha256': 'a' * 64,
  },
};
Map<String, String> environmentFor(Map<String, Object?> data) {
  final bytes = utf8.encode(jsonEncode(data));
  return {
    'QA_NATIVE_CODEC_PHASE_ADMITTED': '1',
    'QA_NATIVE_CODEC_CAPS_B64': base64Encode(bytes),
    'QA_NATIVE_CODEC_CAPS_SHA256': sha256.convert(bytes).toString(),
  };
}

void main() {
  test('expired readback deadline never starts another native read', () async {
    var calls = 0;
    await expectLater(
      qaReadCodecWithinDeadline(() async {
        calls++;
        return 'VP8';
      }, DateTime.now().subtract(const Duration(seconds: 1))),
      throwsA(isA<async.TimeoutException>()),
    );
    expect(calls, 0);
  });
  test(
    'late native read cannot resume successful verification after timeout',
    () async {
      final completer = async.Completer<String>();
      var accepted = false;
      final read =
          qaReadCodecWithinDeadline(
            () => completer.future,
            DateTime.now().add(const Duration(milliseconds: 30)),
          ).then((value) {
            accepted = true;
            return value;
          });
      await expectLater(read, throwsA(isA<async.TimeoutException>()));
      completer.complete('VP8');
      await Future<void>.delayed(Duration.zero);
      expect(accepted, false);
    },
  );

  test('known connected SFU unrestricted declaration differs from unknown or denied', () {
    expect(
      qaSharedCodecProfile(
        'vp8',
        caps('vp8'),
        [caps('vp8')],
        [],
        sfuNoExplicitRestriction: true,
      ),
      'vp8',
    );
    expect(
      () => qaSharedCodecProfile('vp8', caps('vp8'), [caps('vp8')], []),
      throwsStateError,
    );
    expect(
      () => qaSharedCodecProfile(
        'vp8',
        caps('vp8'),
        [caps('vp8')],
        null,
        sfuNoExplicitRestriction: true,
      ),
      throwsStateError,
    );
    expect(
      () => qaSharedCodecProfile(
        'h264',
        caps('h264', 'profile-level-id=42e01f;packetization-mode=1'),
        [caps('h264', 'profile-level-id=42e01f;packetization-mode=1')],
        ['vp8'],
        sfuNoExplicitRestriction: true,
      ),
      throwsStateError,
    );
    expect(
      () => qaSharedCodecProfile(
        'vp8',
        null,
        [caps('vp8')],
        [],
        sfuNoExplicitRestriction: true,
      ),
      throwsStateError,
    );
  });
  test(
    'sandbox-safe capability payload retains measured ownership and hash',
    () {
      final value = qaReadCodecCapabilitiesEnvironment(
        environmentFor(environmentPayload()),
      );
      expect(value['schema_version'], 1);
      expect(value['measured'], true);
      expect((value['receiver_capabilities'] as List).length, 1);
    },
  );
  test(
    'sandbox-safe capability payload rejects corrupt hash and ownership',
    () {
      final env = environmentFor(environmentPayload());
      expect(
        () => qaReadCodecCapabilitiesEnvironment({
          ...env,
          'QA_NATIVE_CODEC_CAPS_SHA256': 'b' * 64,
        }),
        throwsStateError,
      );
      expect(
        () => qaReadCodecCapabilitiesEnvironment({
          ...env,
          'QA_NATIVE_CODEC_PHASE_ADMITTED': '0',
        }),
        throwsStateError,
      );
      final data = environmentPayload();
      data['ownership_proof'] = {'kind': 'unowned'};
      expect(
        () => qaReadCodecCapabilitiesEnvironment(environmentFor(data)),
        throwsStateError,
      );
    },
  );
  test('sandbox-safe capability payload rejects unknown/private schema and oversized input', () {
    for (final data in [
      {...environmentPayload(), 'password': 'private'},
      {...environmentPayload(), 'schema_version': 2},
      {...environmentPayload(), 'measured': false},
      {...environmentPayload(), 'receiver_capabilities': []},
    ]) {
      expect(
        () => qaReadCodecCapabilitiesEnvironment(environmentFor(data)),
        throwsStateError,
      );
    }
    expect(
      () => qaReadCodecCapabilitiesEnvironment({
        'QA_NATIVE_CODEC_PHASE_ADMITTED': '1',
        'QA_NATIVE_CODEC_CAPS_B64': 'a' * 90000,
        'QA_NATIVE_CODEC_CAPS_SHA256': 'a' * 64,
      }),
      throwsStateError,
    );
  });
  test('sandbox-safe capability payload rejects raw SDP and unexpected codec fields', () {
    for (final row in [
      {
        'mimeType': 'video/VP8',
        'clockRate': 90000,
        'sdpFmtpLine': '',
        'track_id': 'private',
      },
      {
        'mimeType': 'video/H264',
        'clockRate': 90000,
        'sdpFmtpLine': 'v=0\r\na=private',
      },
      {'mimeType': 'video/unknown', 'clockRate': 90000, 'sdpFmtpLine': ''},
    ]) {
      final data = environmentPayload();
      data['receiver_capabilities'] = [
        [row],
      ];
      expect(
        () => qaReadCodecCapabilitiesEnvironment(environmentFor(data)),
        throwsStateError,
      );
    }
  });
  test('admission diagnostic excludes paths/messages/raw unknown MIME', () {
    final record = qaCodecAdmissionDiagnostic(
      phase: 'caps_read',
      errorClass: 'FileSystemException',
      osErrorCode: 13,
      reason: '/private/path/token',
      roomConnected: true,
      sfuCodecs: ['video/VP8', 'secret/room'],
      senderCodecs: 7,
      viewerEndpoints: 1,
    );
    expect(record['error_class'], 'FileSystemException');
    expect(record['os_error_code'], 13);
    expect(record['reason'], 'unknown');
    expect(record['sfu_known_codecs'], ['vp8']);
    expect(record.toString(), isNot(contains('private')));
    expect(record.toString(), isNot(contains('secret')));
  });
  test(
    'QA diagnostics override absent delegates unchanged capture options',
    () {
      const options = ScreenShareCaptureOptions(
        sourceId: 'qa-window',
        captureEngine: 'screen_capture_kit',
        maxFrameRate: 60,
      );
      expect(
        identical(qaCaptureDiagnosticsOptions(options, null), options),
        true,
      );
    },
  );
  test(
    'QA diagnostics override preserves capture engine/source/quality/audio',
    () {
      const options = ScreenShareCaptureOptions(
        sourceId: 'qa-window',
        captureEngine: 'screen_capture_kit',
        maxFrameRate: 60,
        captureScreenAudio: true,
        useiOSBroadcastExtension: true,
        preferCurrentTab: true,
        selfBrowserSurface: 'exclude',
      );
      for (final value in ['0', '1']) {
        final updated = qaCaptureDiagnosticsOptions(options, value);
        expect(updated.captureDiagnosticsEnabled, value == '1');
        expect(updated.deviceId, options.deviceId);
        expect(updated.captureEngine, options.captureEngine);
        expect(updated.maxFrameRate, options.maxFrameRate);
        expect(updated.params, options.params);
        expect(updated.captureScreenAudio, true);
        expect(updated.useiOSBroadcastExtension, true);
        expect(updated.preferCurrentTab, true);
        expect(updated.selfBrowserSurface, 'exclude');
      }
    },
  );
  test('QA diagnostics override rejects invalid values before capture', () {
    for (final value in ['', 'true', 'on', '2']) {
      expect(
        () => qaCaptureDiagnosticsOptions(
          const ScreenShareCaptureOptions(),
          value,
        ),
        throwsStateError,
      );
    }
  });
  test('negotiation receipt requires owned marked caps directory', () async {
    final folder = await Directory.systemTemp.createTemp('qa331-receipt-test-');
    try {
      final canonicalFolder = await folder.resolveSymbolicLinks();
      final caps = File('$canonicalFolder/codec-receivers-private.json');
      await caps.writeAsString('{}');
      await expectLater(
        qaWriteCodecReadbackReceipt(
          caps,
          const NativeScreenProfileReadback({}, [], codec: 'VP8'),
        ),
        throwsStateError,
      );
      expect(
        File('${folder.path}/codec-negotiation-private.json').existsSync(),
        false,
      );
      await File('${folder.path}/.qa98325-owned')
          .writeAsString('owned physical Mac QA\n');
      await qaWriteCodecReadbackReceipt(
        caps,
        const NativeScreenProfileReadback({}, [], codec: 'VP8'),
      );
      final result = jsonDecode(
        await File('${folder.path}/codec-negotiation-private.json')
            .readAsString(),
      );
      expect(result['actual_codec'], 'vp8');
      expect(folder.listSync().whereType<Directory>(), isEmpty);
    } finally {
      await folder.delete(recursive: true);
    }
  });
  test(
    'actual MIME codec readback is case insensitive and unknown is rejected',
    () {
      expect(qaActualCodecName('VP8'), 'vp8');
      expect(qaActualCodecName('H264'), 'h264');
      expect(qaActualCodecName('VP9'), isNull);
      expect(qaActualCodecName(null), isNull);
    },
  );
  test('negotiation receipt excludes sender/track IDs and raw SDP', () {
    final value = qaCodecReadbackProjection(
      NativeScreenProfileReadback(
        {'actual_width': 1920, 'actual_height': 1080, 'source_id': 'private'},
        [
          rtc.RTCRtpEncoding(
            rid: 'private',
            maxFramerate: 60,
            maxBitrate: 4000000,
            scaleResolutionDownBy: 1,
          ),
        ],
        codec: 'H264',
        codecFmtp: 'profile-level-id=42e01f;packetization-mode=1;level-asymmetry-allowed=1;private=value',
      ),
    );
    expect(value['actual_codec'], 'h264');
    expect(
      value['codec_fmtp'],
      'profile-level-id=42e01f;packetization-mode=1;level-asymmetry-allowed=1',
    );
    expect(value.toString(), isNot(contains('private')));
    expect((value['encodings'] as List).single['max_fps'], 60);
    expect(qaCodecReadbackProjection(null)['actual_codec'], isNull);
  });
  const baseline = 'profile-level-id=42e01f;packetization-mode=1';
  test('different known constrained-baseline levels remain compatible', () {
    expect(
      qaSharedCodecProfile(
        'h264',
        caps(
          'h264',
          'profile-level-id=42e033;packetization-mode=1;level-asymmetry-allowed=1',
        ),
        [caps('h264', '$baseline;level-asymmetry-allowed=1')],
        ['video/h264'],
      ),
      '42e01f:1',
    );
  });
  test(
    'unknown level, profile, packetization and duplicate parameters defer',
    () {
      for (final fmtp in [
        'profile-level-id=42e000;packetization-mode=1',
        'profile-level-id=640c1f;packetization-mode=1',
        'profile-level-id=42e01f;packetization-mode=0',
        '$baseline;packetization-mode=0',
        '$baseline;level-asymmetry-allowed=2',
      ]) {
        expect(
          () => qaSharedCodecProfile(
            'h264',
            caps('h264', baseline),
            [caps('h264', fmtp)],
            ['h264'],
          ),
          throwsStateError,
        );
      }
    },
  );
  test(
    'unknown and mixed viewer capabilities defer without automatic fallback',
    () {
      for (final receivers in <List<dynamic>>[
        [],
        [null],
        [caps('h264', baseline), caps('vp8')],
      ]) {
        expect(
          () => qaSharedCodecProfile(
            'h264',
            caps('h264', baseline),
            receivers,
            ['h264', 'vp8'],
          ),
          throwsStateError,
        );
      }
      expect(
        () => qaSharedCodecProfile(
          'h264',
          caps('h264', baseline),
          [caps('h264', baseline)],
          ['vp8'],
        ),
        throwsStateError,
      );
    },
  );
  test('explicit VP8 experiment still needs every endpoint capability', () {
    expect(
      qaSharedCodecProfile('vp8', caps('vp8'), [caps('vp8')], ['video/vp8']),
      'vp8',
    );
    expect(
      () => qaSharedCodecProfile('vp8', null, [caps('vp8')], ['vp8']),
      throwsStateError,
    );
  });
  test('actual FMTP must fit admitted common profile and level', () {
    expect(
      qaActualFmtpAccepted(
        '42e01f:1',
        'profile-level-id=42e01f;packetization-mode=1',
      ),
      true,
    );
    expect(
      qaActualFmtpAccepted(
        '42e01f:1',
        'profile-level-id=42e01e;packetization-mode=1',
      ),
      true,
    );
    expect(
      qaActualFmtpAccepted(
        '42e01f:1',
        'profile-level-id=42e033;packetization-mode=1',
      ),
      false,
    );
    expect(
      qaActualFmtpAccepted(
        '42e01f:1',
        'profile-level-id=640c1f;packetization-mode=1',
      ),
      false,
    );
    expect(qaActualFmtpAccepted('42e01f:1', null), false);
  });
}
