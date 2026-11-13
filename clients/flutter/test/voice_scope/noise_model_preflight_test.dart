import 'dart:async';

import 'package:boohtacord_desktop/src/services/native_noise_model_preflight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waits for model before allowing microphone capture', () async {
    final reasons = <String?>[
      'awaiting-model',
      'awaiting-model',
      'awaiting-audio',
    ];
    final result = await waitForNoiseModel(
      enabled: true,
      active: () => true,
      poll: () async => reasons.removeAt(0),
      interval: Duration.zero,
    );
    expect(result.status, ModelPreflightStatus.ready);
    expect(reasons, isEmpty);
  });

  test('already active processing is also model ready', () async {
    final result = await waitForNoiseModel(
      enabled: true,
      active: () => true,
      poll: () async => 'active',
    );
    expect(result.status, ModelPreflightStatus.ready);
  });

  test('failure and timeout do not allow capture', () async {
    final failure = await waitForNoiseModel(
      enabled: true,
      active: () => true,
      poll: () async => 'processor-failed',
    );
    expect(failure.status, ModelPreflightStatus.failed);
    expect(failure.reason, 'processor-failed');
    final timeout = await waitForNoiseModel(
      enabled: true,
      active: () => true,
      poll: () async => 'awaiting-model',
      timeout: Duration.zero,
    );
    expect(timeout.status, ModelPreflightStatus.failed);
    expect(timeout.reason, 'model-timeout');
  });

  test(
    'cancelled generation cannot become ready after a delayed reply',
    () async {
      final response = Completer<String?>();
      var current = true;
      final pending = waitForNoiseModel(
        enabled: true,
        active: () => current,
        poll: () => response.future,
      );
      current = false;
      response.complete('awaiting-audio');
      expect((await pending).status, ModelPreflightStatus.cancelled);
    },
  );

  test('unrelated modes do not query or change native state', () async {
    var calls = 0;
    final result = await waitForNoiseModel(
      enabled: false,
      active: () => true,
      poll: () async {
        calls++;
        return null;
      },
    );
    expect(result.status, ModelPreflightStatus.ready);
    expect(calls, 0);
  });

  test('failed model selects fallback, cancellation does not', () async {
    final reasons = <String>[];
    final ok = await prepareNoiseModelForCapture(
      enabled: true,
      active: () => true,
      poll: () async => 'processor-failed',
      fallback: (reason) async => reasons.add(reason),
    );
    expect(ok, true);
    expect(reasons, ['processor-failed']);
    final cancelled = await prepareNoiseModelForCapture(
      enabled: true,
      active: () => false,
      poll: () async => 'awaiting-audio',
      fallback: (reason) async => reasons.add(reason),
    );
    expect(cancelled, false);
    expect(reasons, ['processor-failed']);
  });
}
