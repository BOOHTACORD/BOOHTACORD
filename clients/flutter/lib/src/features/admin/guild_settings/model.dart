import '../../guild/profile/model.dart';

class GuildSettings extends GuildProfile {
  const GuildSettings(super.name, super.revision, this.welcome, {this.afkChannelID, this.afkTimeoutSeconds = 0});
  final String? welcome;
  final String? afkChannelID;
  final int afkTimeoutSeconds;
  factory GuildSettings.fromJson(Map<String, dynamic> json) {
    final profile = GuildProfile.fromJson(json),
        welcome = json['welcome_channel_id'];
    if (welcome != null &&
        (welcome is! String ||
            !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(welcome))) {
      throw const FormatException('Некорректный welcome-канал.');
    }
    final afkChannel = json['afk_channel_id'], timeout = json['afk_timeout_seconds'] ?? 0;
    if (afkChannel != null && (afkChannel is! String || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(afkChannel))) throw const FormatException('Некорректный AFK-канал.');
    if (timeout is! int || timeout < 0 || timeout > 86400 || (afkChannel == null) != (timeout == 0)) throw const FormatException('Некорректный интервал AFK.');
    return GuildSettings(profile.name, profile.revision, welcome as String?, afkChannelID: afkChannel as String?, afkTimeoutSeconds: timeout);
  }
}
