import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/api_client.dart';
import '../profile/quality.dart';
import '../../../services/screen_share_metrics.dart';
import '../../../services/screen_share_metrics_generation_gate.dart';
import '../../../telemetry/report_media/sender.dart';
import 'layers.dart';
import '../runtime_apply/options.dart';
import 'report_cadence.dart';
import 'sample.dart';
import 'stats_poller.dart';
import 'report_sample.dart';

class ScreenShareMetricsController {
  ScreenShareMetricsController(
    this.api,
    this.scope, {
    required this.readRoom,
    required this.isSharing,
    required this.readQuality,
    required this.changed,
    this.captureObservation,
  });
  final void Function() changed;
  final Future<void> Function(ScreenAdaptationObservation)? Function()?
  captureObservation;
  ScreenShareSenderReport? report;
  DateTime? sampledAt;
  final ApiClient api;
  final SessionScope scope;
  final Room? Function() readRoom;
  final bool Function() isSharing;
  final ScreenShareQuality Function() readQuality;
  Timer? timer;
  Timer? reportTimer;
  LocalVideoTrack? track;
  ScreenShareSenderSnapshot? previous;
  String? previousLayerId;
  num? totalBitrateBps;
  List<ScreenSenderLayerMetrics> layerDiagnostics = const [];
  ScreenStatsPoller? statsPoller;
  final layerSampler = ScreenSenderLayerSampler();
  final gate = ScreenShareMetricsGenerationGate();
  final telemetry = SenderMediaTelemetry();
  final sampleClock = Stopwatch()..start();
  final reportCadence = ScreenShareReportCadence();
  Map<String, Object> reportMeasurementFields = const {
    'stats_source': 'unsupported',
    'collection_state': 'unavailable',
  };
  double? sampledAtMonotonicMs;
  Completer<void>? reportAbort;
  int? reportBusyGeneration;
  int? reportServerRevision;

  void start(LocalVideoTrack track) {
    stop();
    final revision = gate.generation;
    this.track = track;
    reportAbort = Completer<void>();
    reportServerRevision = api.transport.session.serverRevision;
    report = ScreenShareSenderReport(
      platform: nativeScreenMetricsPlatform(defaultTargetPlatform)!,
      state: 'waiting_first_frame',
    );
    reportMeasurementFields = unavailableReportFields();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(sample(track, revision));
    });
    reportTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(reportLatest(track, revision));
    });
    unawaited(sample(track, revision));
    unawaited(reportLatest(track, revision));
  }

  void stop() {
    gate.nextGeneration();
    final abort = reportAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
    reportAbort = null;
    reportServerRevision = null;
    timer?.cancel();
    timer = null;
    reportTimer?.cancel();
    reportTimer = null;
    reportBusyGeneration = null;
    statsPoller?.clear();
    statsPoller = null;
    track = null;
    previous = null;
    previousLayerId = null;
    totalBitrateBps = null;
    layerDiagnostics = const [];
    layerSampler.clear();
    sampleClock.reset();
    reportCadence.clear();
    report = null;
    sampledAt = null;
    sampledAtMonotonicMs = null;
    reportMeasurementFields = const {
      'stats_source': 'unsupported',
      'collection_state': 'unavailable',
    };
    telemetry.clear();
  }

  Map<String, Object> unavailableReportFields() => {
    'target_resolution': readQuality().resolution,
    'target_fps': readQuality().frameRate,
    'connection_quality':
        readRoom()?.localParticipant?.connectionQuality.name.toUpperCase() ??
        ConnectionQuality.unknown.name.toUpperCase(),
    'stats_source': 'unsupported',
    'collection_state': 'unavailable',
  };
}
