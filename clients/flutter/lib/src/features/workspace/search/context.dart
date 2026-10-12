import '../../../models.dart';
import '../lifecycle/controller.dart';

extension WorkspaceSearchContext on WorkspaceController {
  Future<void> openSearchContext(
    SearchMessage target, {
    String? heading,
  }) async {
    final ticket = scope.capture();
    if (!accepts(ticket)) return;
    restoreSearchLauncherFocus = true;
    final sequence = ++searchContextSequence;
    bool active() => accepts(ticket) && sequence == searchContextSequence;
    searchContextMessage = target;
    searchContextHeading = heading ?? 'Контекст найденного сообщения';
    searchContextTextMessages = const [];
    searchContextDirectMessages = const [];
    searchContextError = null;
    loadingSearchContext = true;
    workspacePanel = WorkspacePanel.searchContext;
    if (!await resolveSearchTarget(target, active)) return;
    changed();
    try {
      if (target.kind == SearchMessageKind.channel) {
        final page = await api.messagePage(
          target.conversationId,
          at: target.id,
        );
        if (!active()) return;
        searchContextTextMessages = page.messages;
        if (!page.messages.any((message) => message.id == target.id)) {
          searchContextError =
              'Найденное сообщение больше недоступно в канале.';
        }
      } else {
        final page = await api.directMessageHistoryPage(
          target.conversationId,
          at: target.id,
        );
        if (!active()) return;
        searchContextDirectMessages = page.messages;
        if (!page.messages.any((message) => message.id == target.id)) {
          searchContextError =
              'Найденное сообщение больше недоступно в диалоге.';
        }
      }
    } catch (cause) {
      if (!active()) return;
      searchContextError = effects.message(cause);
    } finally {
      if (active()) {
        loadingSearchContext = false;
        changed();
      }
    }
  }
}
