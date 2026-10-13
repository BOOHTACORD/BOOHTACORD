import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../profile/quality.dart';
import '../lifecycle/controller.dart';
import 'guard.dart';

extension ScreenShareQualityUpdate on ScreenShareController {
  Future<void> updateScreenShareQuality(
    ScreenShareQuality requested, {
    bool fromSupervisor = false,
  }) {
    if (disposed || phase != ScreenSharePhase.sharing) return Future.value();
    final track = activeTrack;
    if (track == null) {
      error = 'Активная видеодорожка демонстрации недоступна.';
      changed();
      return Future.value();
    }
    if (!fromSupervisor) {
      userQualityCeiling = requested;
      manualQualityRevision++;
      adaptation.invalidate();
    }
    final activePlan = quality.capturePlan(defaultTargetPlatform);
    final requestedPlan = requested.capturePlan(defaultTargetPlatform);
    qualityIntentRevision++;
    pendingQualityUpdate = null;
    pendingQualityTicket = null;
    pendingQualityRoom = null;
    if (requestedPlan.requiresRestartFrom(activePlan)) {
      captureRestartRequired = true;
      error =
          'Чтобы применить ${requested.resolution}p${requested.frameRate}, '
          'остановите демонстрацию и запустите её снова, выбрав этот профиль. '
          'Текущая демонстрация продолжает работать с прежними параметрами.';
      changed();
      return Future<void>.value();
    }
    captureRestartRequired = false;
    pendingQualityUpdate = requested;
    pendingQualityTicket = scope.capture();
    pendingQualityTransportTicket = api.transport.session.scope.capture();
    pendingQualityServer = api.transport.session.serverRevision;
    pendingQualityRoom = readRoom();
    pendingQualityLifecycleRevision = revision;
    final current = qualityUpdateOperation;
    if (current != null) return current;
    final operation = Future<void>.microtask(_drainQualityUpdates);
    qualityUpdateOperation = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(qualityUpdateOperation, operation)) {
          qualityUpdateOperation = null;
        }
      }),
    );
    return operation;
  }

  Future<void> _drainQualityUpdates() async {
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
