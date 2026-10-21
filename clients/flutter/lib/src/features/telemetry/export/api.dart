import 'dart:io';

import '../../../core/http/transport.dart';
import 'session_processor.dart';

class TelemetryExportApi {
  TelemetryExportApi(this.transport);
  final ApiTransport transport;

  Future<void> submitClientSpans(List<int> body) async {
    transport.ensureCurrent();
    final session = transport.session.telemetry;
    final owner = session.snapshot();
    final headers = await transport.headers();
    if (owner.binding == null || !session.current(owner)) return;
    final response = await transport.raw.post(
      transport.uri('/telemetry/traces'),
      headers: {
        ...headers,
        'x-telemetry-session': owner.binding!,
        if (owner.installation != null)
          'x-installation-id': owner.installation!,
        'content-type': 'application/x-protobuf',
        'x-client-platform': Platform.operatingSystem,
      },
      body: body,
    );
    transport.ensureCurrent();
    if (!session.current(owner)) return;
    if (response.statusCode != 202) {
      // Keep diagnostics actionable without logging the relay's response body,
      // which is not a trusted or privacy-safe source of details.
      throw RelayFailure(
        response.statusCode,
        Duration(
          seconds: int.tryParse(response.headers['retry-after'] ?? '') ?? 0,
        ),
      );
    }
    final accepted =
        int.tryParse(response.headers['x-telemetry-accepted'] ?? '') ?? 0;
    final rejected =
        int.tryParse(response.headers['x-telemetry-rejected'] ?? '') ?? 0;
    if (accepted < 0 || rejected < 0 || accepted + rejected > 32) return;
    telemetryExportStatus.accepted += accepted;
    telemetryExportStatus.rejected += rejected;
    if (accepted > 0) telemetryExportStatus.lastAcceptedAt = DateTime.now();
  }
}
