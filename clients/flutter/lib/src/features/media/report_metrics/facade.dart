import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin ScreenMetricsReportFacade on ApiFacadeBase {
  late final _screenMetricsReport = ScreenMetricsReportApi(transport);
  late final _screenTelemetryReport = ScreenTelemetryReportApi(transport);

  Future<void> reportScreenShareMetrics(
    Map<String, Object> report, {
    Duration timeout = const Duration(seconds: 10),
    Future<void>? abortTrigger,
  }) => transport.run(
    () => _screenMetricsReport.reportScreenShareMetrics(
      report,
      timeout: timeout,
      abortTrigger: abortTrigger,
    ),
  );

  Future<void> reportScreenTelemetry(
    String ownerLeaseId,
    Map<String, Object?> envelope, {
    Duration timeout = const Duration(seconds: 10),
    Future<void>? abortTrigger,
  }) => transport.run(
    () => _screenTelemetryReport.reportScreenTelemetry(
      ownerLeaseId,
      envelope,
      timeout: timeout,
      abortTrigger: abortTrigger,
    ),
  );
}
