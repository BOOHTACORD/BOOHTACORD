import '../../../app_state.dart';
import '../../../models.dart';

List<Map<String, String>> notificationConversationChoices(AppState state) =>
    <Map<String, String>>[
      for (final channel
          in state.workspace.topology?.categories
                  .expand((c) => c.channels)
                  .where((c) => c.kind == ChannelKind.text) ??
              <GuildChannel>[])
        {'kind': 'CHANNEL', 'id': channel.id, 'label': '# ${channel.name}'},
      for (final direct in state.workspace.directMessages)
        {
          'kind': 'DIRECT_MESSAGE',
          'id': direct.id,
          'label': 'Личные: ${direct.displayName}',
        },
    ];
