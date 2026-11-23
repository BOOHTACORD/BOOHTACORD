import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import 'fakes.dart';
import 'quality_fakes.dart';

class WindowsSourceTrack extends FakeScreenTrack {
  @override
  ScreenShareCaptureOptions get currentOptions =>
      const ScreenShareCaptureOptions(
        sourceId: 'owned-window',
        captureScreenAudio: true,
        maxFrameRate: 15,
      );
}

class WindowsRestartDriver extends QualityScreenDriver {
  Object? captureFailure;
  Completer<void>? stopGate;
  final enteredStop = Completer<void>();
  @override
  Future<LocalVideoTrack> capture(ScreenShareCaptureOptions options) {
    if (captureFailure != null) {
      captureOptions = options;
      return Future.error(captureFailure!);
    }
    return super.capture(options);
  }

  @override
  Future<void> stop(Room room) async {
    stopCalls++;
    if (!enteredStop.isCompleted) enteredStop.complete();
    await stopGate?.future;
  }
}
