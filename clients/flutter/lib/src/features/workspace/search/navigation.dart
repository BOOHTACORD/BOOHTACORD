import '../lifecycle/controller.dart';
import 'session.dart';
import '../../../models.dart';

extension WorkspaceSearchNavigation on WorkspaceController {
  void openSearchPanel({bool currentConversation = false, bool pins = false}) {
    searchSessionEpoch++;
    searchPinsRequested =
        pins &&
        selectedDirectMessage == null &&
        selectedChannel?.kind == ChannelKind.text;
    if (currentConversation) {
      final direct = selectedDirectMessage;
      final key = direct != null
          ? 'dm:${direct.id}'
          : selectedChannel == null
          ? null
          : 'channel:${selectedChannel!.id}';
      if (key != null) {
        final old = searchSessions[key];
        searchSessions[key] = WorkspaceSearchSession(
          query: old?.query ?? '',
          scope: 'current',
          scrollOffset: old?.scope == 'current' ? old!.scrollOffset : 0,
          shouldSearch: old?.scope == 'current' && old!.shouldSearch,
        );
      }
    }
    restoreSearchLauncherFocus = !currentConversation;
    searchContextSequence++;
    searchOriginChannel = selectedChannel;
    searchOriginDirectMessage = selectedDirectMessage;
    searchContextMessage = null;
    searchContextHeading = 'Контекст найденного сообщения';
    searchContextTextMessages = const [];
    searchContextDirectMessages = const [];
    searchContextError = null;
    workspacePanel = WorkspacePanel.search;
    changed();
  }

  void closeSearchPanel({bool? restoreLauncherFocus}) {
    restoreSearchLauncherFocus =
        restoreLauncherFocus ?? restoreSearchLauncherFocus;
    searchContextSequence++;
    loadingSearchContext = false;
    searchContextHeading = 'Контекст найденного сообщения';
    if (workspacePanel == WorkspacePanel.search) {
      workspacePanel = WorkspacePanel.none;
    }
    searchOriginChannel = null;
    searchOriginDirectMessage = null;
    changed();
  }

  Future<void> returnFromSearchContext() async {
    searchContextSequence++;
    final channel = searchOriginChannel;
    final directMessage = searchOriginDirectMessage;
    searchOriginChannel = null;
    searchOriginDirectMessage = null;
    searchContextMessage = null;
    searchContextHeading = 'Контекст найденного сообщения';
    searchContextTextMessages = const [];
    searchContextDirectMessages = const [];
    searchContextError = null;
    workspacePanel = WorkspacePanel.none;
    if (channel != null) {
      await selectChannel(channel);
    } else if (directMessage != null) {
      await openDirectConversation(directMessage);
    } else {
      changed();
    }
  }
}
