import 'dart:convert';

import '../../../core/http/facade_base.dart';
import '../../../core/http/api_failure.dart';
import 'model.dart';

mixin AdminTelemetryFacade on ApiFacadeBase {
  Future<TelemetrySettings> readTelemetrySettings() => transport.run(
    () async => TelemetrySettings.fromJson(
      await transport.checked(
        await transport.client.get(
          transport.uri('/admin/telemetry'),
          headers: {...await transport.headers(), 'cache-control': 'no-store'},
        ),
      ),
    ),
  );
  Future<TelemetrySettings> updateTelemetrySettings(
    String mode,
    String endpoint,
    bool confirmed,
  ) => transport.run(() async {
    if (!['central', 'local_only'].contains(mode) ||
        mode == 'central' && (!confirmed || !validTelemetryEndpoint(endpoint)))
      throw const ApiFailure(
        'Подтвердите согласие и укажите HTTPS-адрес центра.',
      );
    return TelemetrySettings.fromJson(
      await transport.checked(
        await transport.client.patch(
          transport.uri('/admin/telemetry'),
          headers: await transport.headers(jsonBody: true),
          body: jsonEncode({
            'mode': mode,
            if (mode == 'central') ...{
              'endpoint': endpoint.trim(),
              'confirmed': true,
            },
          }),
        ),
      ),
    );
  });
}
