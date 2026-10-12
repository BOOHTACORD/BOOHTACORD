import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_share_quality.dart';
import 'controller.dart';
import 'publish_capture.dart';

extension ScreenShareStart on ScreenShareController {
  Future<void> startScreenShare({
    String? sourceId,
    ScreenShareQuality? quality,
    VideoDimensions? sourceDimensions,
    bool captureScreenAudio = false,
  }) async {
    final ticket = scope.capture();
    final admitted = revision;
    await closing;
    if (disposed || !ticket.isActive || admitted != revision) return;
    final room = readRoom();
    if (room == null || room.localParticipant == null || !voiceReady()) {
      error = 'Подключитесь к голосовому каналу перед демонстрацией.';
      phase = ScreenSharePhase.error;
      changed();
      return;
    }
    if (starting != null || phase == ScreenSharePhase.sharing) return;
    phase = ScreenSharePhase.starting;
    error = null;
    this.quality = quality ?? this.quality;
    userQualityCeiling = this.quality;
    manualQualityRevision++;
    adaptation.invalidate();
    captureRestartRequired = false;
    this.sourceDimensions = sourceDimensions;
    final expected = ++revision;
    final operation = publishCapture(
      room,
      ticket,
      expected,
      sourceId,
      sourceDimensions,
      captureScreenAudio,
    );
    starting = operation;
    changed();
    try {
      await operation;
    } finally {
      if (identical(starting, operation)) starting = null;
    }
  }
}
