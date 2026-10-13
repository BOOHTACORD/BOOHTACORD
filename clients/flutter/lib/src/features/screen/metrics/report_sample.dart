import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' show LocalVideoTrack;

import '../../../core/http/api_failure.dart';
import '../../../core/session/scope.dart';
import '../../media/report_metrics/api.dart';
import '../../../services/screen_share_diagnostics.dart';
import 'controller.dart';
import 'report_payload.dart';

extension ScreenReportSample on ScreenShareMetricsController {
  Future<void> reportLatest(LocalVideoTrack track, int revision) async {
    final ticket = scope.capture();
    if (revision != gate.generation ||
        !identical(track, this.track) ||
        !isSharing()) {
      return;
    }
    if (!ticket.isActive ||
        reportServerRevision != api.transport.session.serverRevision) {
      final abort = reportAbort;
      if (abort != null && !abort.isCompleted) abort.complete();
      return;
    }
    if (reportBusyGeneration == revision ||
        report == null ||
        reportAbort == null) {
      return;
    }

    final nowMs = sampleClock.elapsedMilliseconds.toDouble();
    if (!reportCadence.isDue(nowMs)) {
      return;
    }
    final currentReport = report!;
    final abort = reportAbort!;
    final payload = buildScreenSenderReportPayload(
      report: currentReport,
      measurementFields: reportMeasurementFields,
      sampledAtMs: sampledAtMonotonicMs,
      nowMs: nowMs,
    );
    reportCadence.markAttempt(nowMs);
    reportBusyGeneration = revision;
    logScreenShareDiagnostic(
      ScreenShareDiagnosticEvent.senderReportStarted,
      platform: defaultTargetPlatform,
    );
    try {
      await api.reportScreenShareMetrics(
        payload,
        timeout: const Duration(seconds: 10),
        abortTrigger: abort.future,
      );
      if (!_isCurrent(ticket, track, revision)) return;
      final finishedAtMs = sampleClock.elapsedMilliseconds.toDouble();
      reportCadence.markSuccess(finishedAtMs);
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.senderReportSent,
        platform: defaultTargetPlatform,
        durationMs: finishedAtMs - nowMs,
      );
    } catch (error) {
      if (revision != gate.generation ||
          !identical(track, this.track) ||
          !isSharing()) {
        return;
      }
      final finishedAtMs = sampleClock.elapsedMilliseconds.toDouble();
      final errorClass = ticket.isActive
          ? _reportErrorClass(error)
          : 'session_invalidated';
      if (ticket.isActive) reportCadence.markFailure(finishedAtMs);
      logScreenShareDiagnostic(
        ScreenShareDiagnosticEvent.senderReportFailed,
        platform: defaultTargetPlatform,
        durationMs: finishedAtMs - nowMs,
        errorClass: errorClass,
        httpStatusClass: _httpStatusClass(error),
      );
    } finally {
      if (reportBusyGeneration == revision) reportBusyGeneration = null;
    }
  }

  bool _isCurrent(SessionTicket ticket, LocalVideoTrack track, int revision) =>
      ticket.isActive &&
      revision == gate.generation &&
      identical(track, this.track) &&
      isSharing();

  String _reportErrorClass(Object error) {
    if (error is TimeoutException) return 'http_timeout';
    if (error is ScreenMetricsReportAborted) return 'session_invalidated';
    if (error is ApiFailure && error.code == 'STALE_SESSION') {
      return 'session_invalidated';
    }
    final status = error is ApiFailure ? error.status : null;
    if (status != null && status >= 400 && status < 500) return 'http_4xx';
    if (status != null && status >= 500 && status < 600) return 'http_5xx';
    return 'network';
  }

  String? _httpStatusClass(Object error) {
    if (error is! ApiFailure || error.status == null) return null;
    final status = error.status!;
    if (status >= 400 && status < 500) return '4xx';
    if (status >= 500 && status < 600) return '5xx';
    return 'other';
  }
}
