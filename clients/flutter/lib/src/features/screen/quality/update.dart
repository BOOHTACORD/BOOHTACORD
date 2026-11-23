import 'dart:async';

import 'package:flutter/foundation.dart';

import '../profile/quality.dart';
import '../lifecycle/controller.dart';
import 'capture_change.dart';
import 'drain.dart';

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
      return applyCaptureProfileChange(this, requested);
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
    final operation = Future<void>.microtask(drainQualityUpdates);
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
}
