import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_share_diagnostics.dart';
import '../../../services/screen_share_metrics.dart';
import 'controller.dart';
import 'livekit_layers.dart';
import 'report_measurements.dart';
import 'stats_poller.dart';
import '../../../telemetry/report_media/sender_sample.dart';

import 'dart:async';

import '../runtime_apply/options.dart';

extension ScreenShareSample on ScreenShareMetricsController {
  Future<void> sample(LocalVideoTrack track, int revision) async {
    final ticket = scope.capture();
    if (!ticket.isActive ||
        revision != gate.generation ||
        !identical(track, this.track) ||
        !isSharing() ||
        !gate.tryEnter(revision)) {
      return;
    }
    try {
      final observe = captureObservation?.call();
      final sender = track.sender;
      statsPoller = sender == null ? null : screenStatsPoller(sender);
      final List<rtc.StatsReport> reports = sender == null
          ? const []
          : await statsPoller!.read(sender.getStats);
      final double? measuredAtMs = sender == null
          ? null
          : sampleClock.elapsedMilliseconds.toDouble();
      if (!ticket.isActive ||
          revision != gate.generation ||
          !identical(track, this.track) ||
          !isSharing()) {
        return;
      }
      final sources = screenSenderSourcesFromReports(reports);
      final layerSample = sampleLiveKitScreenLayers(
        layerSampler,
        sources,
        sampleClock.elapsedMilliseconds.toDouble(),
      );
      layerDiagnostics = layerSample.diagnostics.layers;
      final measurementFields = senderMeasurementFields(layerDiagnostics);
      final total = measurementFields['total_bitrate_kbps'];
      totalBitrateBps = total is num ? total * 1000 : null;
      final selected = layerSample.selected;
      if (previousLayerId != layerSample.diagnostics.selected?.id) {
        previous = null;
      }
      previousLayerId = layerSample.diagnostics.selected?.id;
      final current = senderSnapshot(selected);
      if (!ticket.isActive ||
          revision != gate.generation ||
          !identical(track, this.track) ||
          !isSharing()) {
        return;
      }
      final report = buildScreenShareSenderReport(
        previous: previous,
        current: current,
        platform: nativeScreenMetricsPlatform(defaultTargetPlatform)!,
      );
      logScreenShareDiagnostic(
        current == null
            ? ScreenShareDiagnosticEvent.senderStatsUnavailable
            : ScreenShareDiagnosticEvent.senderStatsSampled,
        platform: defaultTargetPlatform,
        senderStatsEntries: reports.length,
        framesSent: current?.framesSent?.round(),
        bytesSent: current?.bytesSent?.round(),
        encodedFramesPerSecond: report.encodedFps?.round(),
      );
      previous = current;
      this.report = report;
      sampledAt = measuredAtMs == null ? null : DateTime.now();
      sampledAtMonotonicMs = measuredAtMs;
      final mediaSamples = sources
          .where(
            (item) => item.counters.id == layerSample.diagnostics.selected?.id,
          )
          .map(
            (item) => SenderMediaSample(
              streamId: item.counters.id,
              timestamp: item.counters.timestampMs,
              frameWidth: item.width,
              frameHeight: item.height,
              packetsSent: item.counters.packetsSent,
              packetsLost: item.counters.packetsLost,
              qualityLimitationReason: item.counters.qualityLimitationReason,
            ),
          )
          .toList(growable: false);
      reportMeasurementFields = Map.unmodifiable({
        ...measurementFields,
        ...telemetry.fields(
          mediaSamples,
          readQuality(),
          readRoom()?.localParticipant?.connectionQuality ??
              ConnectionQuality.unknown,
        ),
      });
      changed();
      unawaited(
        observe?.call(
          ScreenAdaptationObservation(
            report,
            List.unmodifiable(layerDiagnostics),
            sampleClock.elapsedMilliseconds.toDouble(),
          ),
        ),
      );
    } catch (error) {
      if (!ticket.isActive ||
          revision != gate.generation ||
          !identical(track, this.track)) {
        return;
      }
      // Some platform WebRTC implementations do not expose sender stats.
      report = ScreenShareSenderReport(
        platform: nativeScreenMetricsPlatform(defaultTargetPlatform)!,
        state: 'waiting_first_frame',
      );
      sampledAt = null;
      sampledAtMonotonicMs = null;
      reportMeasurementFields = Map.unmodifiable(unavailableReportFields());
      changed();
      layerSampler.clear();
      layerDiagnostics = const [];
      previous = null;
      previousLayerId = null;
      totalBitrateBps = null;
      telemetry.clear();
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.senderStatsUnavailable,
        platform: defaultTargetPlatform,
        errorType: error.runtimeType.toString(),
      );
    } finally {
      gate.leave(revision);
    }
  }
}

ScreenShareSenderSnapshot? senderSnapshot(ScreenSenderLayerSource? selected) =>
    selected == null
    ? null
    : screenShareSenderSnapshotFromStats([
        ScreenShareSenderStats(
          timestampMs: selected.counters.timestampMs,
          frameWidth: selected.counters.width,
          frameHeight: selected.counters.height,
          bytesSent: selected.counters.bytesSent,
          framesSent: selected.counters.encodedFrames,
          roundTripTimeSeconds: selected.roundTripTimeSeconds,
        ),
      ]);
