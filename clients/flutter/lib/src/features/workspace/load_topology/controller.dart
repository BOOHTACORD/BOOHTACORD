import '../../../models.dart';
import '../lifecycle/controller.dart';

extension WorkspaceTopology on WorkspaceController {
  Future<void> refreshTopology({bool strict = false}) async {
    final ticket = scope.capture();
    if (!accepts(ticket)) return;
    try {
      final result = await api.topology();
      if (!accepts(ticket)) return;
      topology = result;
      final all = result.categories.expand((category) => category.channels);
      if (selectedChannel != null &&
          !all.any((channel) => channel.id == selectedChannel!.id)) {
        effects.invalidateText();
        selectedChannel = null;
        effects.clearText();
      }
      final previous = selectedChannel;
      selectedChannel = all.where((c) => c.id == previous?.id).firstOrNull;
      if (navigationSection == NavigationSection.channels)
        selectedChannel ??= all
            .where((channel) => channel.kind == ChannelKind.text)
            .firstOrNull;
      if (previous == null && selectedChannel?.kind == ChannelKind.text) {
        await selectChannel(selectedChannel!);
      }
    } catch (cause) {
      if (strict) rethrow;
      if (accepts(ticket)) effects.error(effects.message(cause));
    }
    if (accepts(ticket)) changed();
  }
}
