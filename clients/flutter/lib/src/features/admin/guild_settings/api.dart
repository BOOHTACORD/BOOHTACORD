import 'dart:convert';

import '../../../core/http/transport.dart';
import 'model.dart';

class GuildSettingsApi {
  GuildSettingsApi(this.transport);
  final ApiTransport transport;
  Future<GuildSettings> read() async => _parse(
    await transport.checked(
      await transport.client.get(
        transport.uri('/admin/guild-settings'),
        headers: {...await transport.headers(), 'cache-control': 'no-store'},
      ),
    ),
  );
  Future<GuildSettings> write(
    String name,
    String? channel,
    int revision,
    [String? afkChannelID, int afkTimeoutSeconds = 0]
  ) async => _parse(
    await transport.checked(
      await transport.client.patch(
        transport.uri('/admin/guild-settings'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          'name': name,
          'welcome_channel_id': channel,
          'expected_revision': revision,
          'afk_channel_id': afkChannelID,
          'afk_timeout_seconds': afkTimeoutSeconds,
        }),
      ),
    ),
  );
  GuildSettings _parse(dynamic body) =>
      GuildSettings.fromJson(body as Map<String, dynamic>);
}
