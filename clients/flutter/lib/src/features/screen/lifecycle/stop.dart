import 'controller.dart';
import '../../telemetry/action_scope/action.dart';
import '../../telemetry/action_scope/failure.dart';

extension ScreenShareStop on ScreenShareController {
  Future<void> stopScreenShare() {
    final previous = closing;
    if (previous != null) return previous;
    adaptation.invalidate();
    captureRestartRequired = false;
    qualityIntentRevision++;
    pendingQualityUpdate = null;
    final operation = closeCapture(++revision);
    closing = operation;
    return operation.whenComplete(() {
      if (identical(closing, operation)) closing = null;
    });
  }

  Future<void> closeCapture(int expected) async {
    ActionScope.current?.step('stop');
    final room = readRoom();
    final pending = starting;
    final wasIdle = phase == ScreenSharePhase.idle;
    final track = activeTrack;
    descriptor.stop();
    activeTrack = null;
    sourceDimensions = null;
    capturedContentVisibility.track(null);
    await stopSampling();
    phase = ScreenSharePhase.stopping;
    changed();
    try {
      await pending;
      if (room != null && !wasIdle) await driver.stop(room);
      await track?.stop();
      await driver.disableBackground();
      if (expected != revision) return;
      phase = ScreenSharePhase.idle;
      error = null;
    } catch (cause) {
      final failure = failureOutcome(cause);
      ActionScope.current?.finish(
        failure.outcome,
        reason: failure.reason == 'network' ? 'dependency' : failure.reason,
      );
      try {
        await track?.stop();
      } catch (_) {}
      if (expected != revision) return;
      phase = ScreenSharePhase.error;
      error =
          'Не удалось остановить демонстрацию: ${screenShareFailureDetail(cause)}';
    }
    changed();
  }
}
