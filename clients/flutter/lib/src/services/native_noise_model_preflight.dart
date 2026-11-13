import 'dart:async';

enum ModelPreflightStatus { ready, failed, cancelled }

class ModelPreflightResult {
  const ModelPreflightResult(this.status, [this.reason]);
  final ModelPreflightStatus status;
  final String? reason;
}

/// Waits for the native model without claiming that audio has been processed.
Future<ModelPreflightResult> waitForNoiseModel({
  required bool enabled,
  required bool Function() active,
  required Future<String?> Function() poll,
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 50),
}) async {
  if (!active()) {
    return const ModelPreflightResult(ModelPreflightStatus.cancelled);
  }
  if (!enabled) return const ModelPreflightResult(ModelPreflightStatus.ready);
  final elapsed = Stopwatch()..start();
  while (active()) {
    final remaining = timeout - elapsed.elapsed;
    if (remaining <= Duration.zero) {
      return const ModelPreflightResult(
        ModelPreflightStatus.failed,
        'model-timeout',
      );
    }
    String? reason;
    try {
      reason = await poll().timeout(remaining);
    } on TimeoutException {
      return active()
          ? const ModelPreflightResult(
              ModelPreflightStatus.failed,
              'model-timeout',
            )
          : const ModelPreflightResult(ModelPreflightStatus.cancelled);
    } catch (_) {
      return active()
          ? const ModelPreflightResult(
              ModelPreflightStatus.failed,
              'hook-error',
            )
          : const ModelPreflightResult(ModelPreflightStatus.cancelled);
    }
    if (!active()) {
      return const ModelPreflightResult(ModelPreflightStatus.cancelled);
    }
    if (reason == 'awaiting-audio' || reason == 'active') {
      return const ModelPreflightResult(ModelPreflightStatus.ready);
    }
    if (reason != 'awaiting-model') {
      return ModelPreflightResult(
        ModelPreflightStatus.failed,
        reason?.isNotEmpty == true ? reason : 'model-state-unknown',
      );
    }
    final delay = timeout - elapsed.elapsed;
    if (delay > Duration.zero) {
      await Future<void>.delayed(interval < delay ? interval : delay);
    }
  }
  return const ModelPreflightResult(ModelPreflightStatus.cancelled);
}

Future<bool> prepareNoiseModelForCapture({
  required bool enabled,
  required bool Function() active,
  required Future<String?> Function() poll,
  required Future<void> Function(String reason) fallback,
}) async {
  final result = await waitForNoiseModel(
    enabled: enabled,
    active: active,
    poll: poll,
  );
  if (result.status == ModelPreflightStatus.cancelled) return false;
  if (result.status == ModelPreflightStatus.failed) {
    await fallback(result.reason ?? 'model-state-unknown');
  }
  return active();
}
