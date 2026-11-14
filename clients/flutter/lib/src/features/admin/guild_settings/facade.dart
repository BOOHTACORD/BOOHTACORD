import '../../../core/http/facade_base.dart';
import 'api.dart';
import 'model.dart';

mixin GuildSettingsFacade on ApiFacadeBase {
  late final _guildSettings = GuildSettingsApi(transport);
  Future<GuildSettings> readGuildSettings() =>
      transport.run(_guildSettings.read);
  Future<GuildSettings> updateGuildSettings(
    String name,
    String? channel,
    int revision,
    [String? afkChannelID, int afkTimeoutSeconds = 0]
  ) => transport.run(() => _guildSettings.write(name, channel, revision, afkChannelID, afkTimeoutSeconds));
}
