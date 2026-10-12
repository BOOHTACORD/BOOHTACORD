import '../lifecycle/controller.dart';

extension WorkspaceSearchNavigation on WorkspaceController {
  void openSearchPanel() {
    restoreSearchLauncherFocus = true;
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

  void closeSearchPanel({bool restoreLauncherFocus = true}) {
    restoreSearchLauncherFocus = restoreLauncherFocus;
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
