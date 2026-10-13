import 'dart:async' as async;

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/metrics/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' show LocalVideoTrack;
import 'package:http/http.dart' as http;

class ErrorApi extends ApiClient {
  ErrorApi(this.error);
  final Object error;
  @override
  Future<void> reportScreenShareMetrics(
    Map<String, Object> report, {
    Duration timeout = const Duration(seconds: 10),
    async.Future<void>? abortTrigger,
  }) => async.Future.error(error);
}

class EmptySender implements rtc.RTCRtpSender {
  @override
  async.Future<List<rtc.StatsReport>> getStats() async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ScreenTrack implements LocalVideoTrack {
  @override
  final rtc.RTCRtpSender sender = EmptySender();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final row in <(Object, String)>[
    (async.TimeoutException('owned HTTP deadline'), 'http_timeout'),
    (
      http.RequestAbortedException(Uri.parse('https://localhost/fixture')),
      'network',
    ),
  ]) {
    test(
      'sender report diagnostic classifies ${row.$2} independently of LiveKit exceptions',
      () async {
        final original = debugPrint;
        final failed = async.Completer<String>();
        debugPrint = (message, {wrapWidth}) {
          if (message != null &&
              message.contains('event=sender_report_failed') &&
              !failed.isCompleted)
            failed.complete(message);
        };
        final prior = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final api = ErrorApi(row.$1);
        final metrics = ScreenShareMetricsController(
          api,
          SessionScope(),
          readRoom: () => null,
          isSharing: () => true,
          readQuality: () => ScreenShareQuality.balanced,
          changed: () {},
        );
        try {
          metrics.start(ScreenTrack());
          final line = await failed.future.timeout(const Duration(seconds: 1));
          expect(line, contains('error_class=${row.$2}'));
        } finally {
          metrics.stop();
          api.transport.raw.close();
          debugPrint = original;
          debugDefaultTargetPlatformOverride = prior;
        }
      },
    );
  }
}
