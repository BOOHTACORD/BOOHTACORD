import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/screen_share_diagnostics.dart';
import '../../telemetry/action_scope/action.dart';
import '../../telemetry/action_scope/failure.dart';
import 'controller.dart';
import '../capture/cancelled.dart';

extension ScreenShareCapturePublish on ScreenShareController {
  Future<void> publishCapture(
    Room room,
    SessionTicket ticket,
    int expected,
    String? sourceId,
    VideoDimensions? dimensions,
    bool captureScreenAudio,
  ) async {
    bool active() => current(ticket, expected, room);
    LocalVideoTrack? pending;
    var publishing = false;
    try {
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.captureRequested,
        platform: defaultTargetPlatform,
      );
      await driver.prepare(active);
      if (!active()) return;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.capturePrepared,
        platform: defaultTargetPlatform,
      );
      ActionScope.current?.step('select');
      final capturePlan = quality.capturePlan(defaultTargetPlatform);
      pending = await driver.capture(
        ScreenShareCaptureOptions(
          sourceId: sourceId,
          captureScreenAudio: captureScreenAudio,
          maxFrameRate: capturePlan.requestedMaxFrameRate.toDouble(),
          params: capturePlan.requestedParameters,
        ),
      );
      if (!active()) return;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.captureCreated,
        platform: defaultTargetPlatform,
        trackEnabled: screenShareTrackEnabled(pending),
      );
      publishing = true;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.publishStarted,
        platform: defaultTargetPlatform,
        trackEnabled: screenShareTrackEnabled(pending),
        localScreenPublications: screenShareLocalPublicationCount(room),
      );
      ActionScope.current?.step('publish');
      await driver.publish(room, pending, quality, dimensions);
      if (!active()) return;
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.publishCompleted,
        platform: defaultTargetPlatform,
        trackEnabled: screenShareTrackEnabled(pending),
        localScreenPublications: screenShareLocalPublicationCount(room),
      );
      published(room, pending);
      pending = null;
    } catch (cause) {
      final cancelled =
          !publishing &&
          (cause is ScreenCaptureCancelled ||
              failureOutcome(cause).outcome == 'cancelled');
      final failure = cancelled
          ? (outcome: 'cancelled', reason: 'disposed')
          : failureOutcome(cause);
      ActionScope.current?.finish(
        failure.outcome,
        reason: failure.reason == 'network' ? 'dependency' : failure.reason,
      );
      logScreenShareDiagnostic(
        publishing
            ? ScreenShareDiagnosticEvent.publishFailed
            : ScreenShareDiagnosticEvent.captureFailed,
        platform: defaultTargetPlatform,
        trackEnabled: screenShareTrackEnabled(pending),
        localScreenPublications: screenShareLocalPublicationCount(room),
        errorType: cause.runtimeType.toString(),
      );
      if (active()) {
        await stopSampling();
        phase = cancelled ? ScreenSharePhase.idle : ScreenSharePhase.error;
        error = cancelled
            ? null
            : 'Не удалось начать демонстрацию экрана: ${screenShareFailureDetail(cause)}';
        changed();
      }
    } finally {
      if (pending != null) {
        try {
          await driver.discard(room, pending);
        } catch (_) {}
      }
      if (!active() || phase != ScreenSharePhase.sharing) {
        await driver.disableBackground();
      }
    }
  }
}
