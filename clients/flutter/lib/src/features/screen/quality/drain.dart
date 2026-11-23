import 'package:livekit_client/livekit_client.dart';

import '../lifecycle/controller.dart';
import 'guard.dart';

extension ScreenShareQualityDrain on ScreenShareController {
  Future<void> drainQualityUpdates() async {
    while (pendingQualityUpdate != null) {
      final requested = pendingQualityUpdate!;
      final ticket = pendingQualityTicket!;
      final room = pendingQualityRoom;
      final transportTicket = pendingQualityTransportTicket!;
      final server = pendingQualityServer;
      final lifecycleRevision = pendingQualityLifecycleRevision;
      final intentRevision = qualityIntentRevision;
      pendingQualityUpdate = null;
      final track = activeTrack;
      descriptor.runtime.configurationChanged();
      bool current() =>
          !disposed &&
          intentRevision == qualityIntentRevision &&
          isCurrentQualitySession(
            this,
            ticket,
            transportTicket,
            server,
            lifecycleRevision,
            room,
          ) &&
          phase == ScreenSharePhase.sharing &&
          identical(activeTrack, track);
      if (track == null || room == null || !current()) continue;
      try {
        final applied = await driver.updateQuality(
          room,
          track,
          requested,
          sourceDimensions,
          current,
        );
        if (!current()) continue;
        if (!applied) throw StateError('Новый профиль не был опубликован.');
        quality = requested;
        error = null;
      } catch (cause) {
        if (current()) {
          if (cause is! ScreenShareProfileUpdateException || !cause.restored) {
            final reason = screenShareFailureDetail(cause);
            final detail =
                'Профиль не подтверждён; демонстрация остановлена: $reason';
            await stopScreenShare();
            if (!disposed) {
              phase = ScreenSharePhase.error;
              error = detail;
            }
          } else {
            error =
                'Не удалось изменить качество: ${screenShareFailureDetail(cause)}';
          }
        }
      }
      changed();
    }
  }
}
