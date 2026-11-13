import '../../../models.dart';
import '../lifecycle/controller.dart';

extension WorkspaceNavigation on WorkspaceController {
  void toggleWorkspacePanel(WorkspacePanel panel) {
    workspacePanel = workspacePanel == panel ? WorkspacePanel.none : panel;
    effects.error(null);
    if (workspacePanel == WorkspacePanel.audio) {
      effects.audioPanelOpened?.call();
    }
    changed();
  }

  Future<void> showDirectMessages() async {
    if (!accepts(scope.capture())) return;
    effects.invalidateText();
    workspacePanel = WorkspacePanel.none;
    navigationSection = NavigationSection.directMessages;
    selectedChannel = null;
    effects.error(null);
    changed();
    await refreshDirectMessages();
  }

  void showChannels() {
    workspacePanel = WorkspacePanel.none;
    navigationSection = NavigationSection.channels;
    selectedDirectMessage = null;
    effects.clearDirect();
    selectedChannel ??= topology?.categories
        .expand((category) => category.channels)
        .where((channel) => channel.kind == ChannelKind.text)
        .firstOrNull;
    changed();
  }

  Future<void> selectChannel(
    GuildChannel channel, {
    bool Function()? socketCurrent,
  }) async {
    if (!accepts(scope.capture())) return;
    workspacePanel = WorkspacePanel.none;
    navigationSection = NavigationSection.channels;
    selectedDirectMessage = null;
    selectedChannel = channel;
    await effects.selectChannel(channel, socketCurrent: socketCurrent);
  }

  Future<void> openDirectConversation(DirectConversation conversation) async {
    if (!accepts(scope.capture())) return;
    effects.invalidateText();
    selectedDirectMessage = conversation;
    selectedChannel = null;
    await effects.openDirect(conversation);
  }
}
