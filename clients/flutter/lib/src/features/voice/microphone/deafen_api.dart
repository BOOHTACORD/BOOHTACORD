import 'dart:convert';

import '../../../core/http/transport.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

Future<void> publishVoiceDeafened(
  ApiTransport transport,
  String leaseId,
  bool deafened,
) => transport.run(() async {
  if (!_uuid.hasMatch(leaseId)) throw ArgumentError.value(leaseId, 'leaseId');
  await transport.checked(
    await transport.client.put(
      transport.uri('/voice/leases/$leaseId/deafen/v1'),
      headers: await transport.headers(jsonBody: true),
      body: jsonEncode({'deafened': deafened}),
    ),
  );
});
