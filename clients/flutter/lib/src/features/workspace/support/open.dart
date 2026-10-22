import '../lifecycle/controller.dart';

extension WorkspaceSupport on WorkspaceController {
  Future<bool> openSupport() async {
    if (supportOpening || !accepts(scope.capture())) return false;
    final ticket = scope.capture();
    final owner = api.transport.session.telemetry.snapshot();
    final sequence = ++supportSequence;
    supportOpening = true;
    supportNotice = null;
    final loading = showDirectMessages();
    final selection = selectionRevision;
    bool current() =>
        accepts(ticket) &&
        sequence == supportSequence &&
        api.transport.session.telemetry.current(owner) &&
        selection == selectionRevision &&
        workspacePanel == WorkspacePanel.none &&
        navigationSection == NavigationSection.directMessages;
    try {
      await loading;
      if (!current()) return false;
      final contact = supportContact;
      if (!contact.available) {
        supportNotice = contact.unavailableMessage;
        return false;
      }
      final id = await api.openDirectMessage(contact.accountId!);
      if (!current()) return false;
      await refreshDirectMessages();
      if (!current()) return false;
      if (!supportContact.available ||
          supportContact.accountId != contact.accountId ||
          supportContact.revision != contact.revision) {
        supportNotice = 'Контакт поддержки изменился. Старые диалоги сохраняют прежних участников. Нажмите ? ещё раз.';
        return false;
      }
      final conversation = directMessages
          .where((value) => value.id == id)
          .firstOrNull;
      if (conversation == null) {
        supportNotice =
            'Не удалось открыть поддержку. Обновите список и повторите.';
        return false;
      }
      await openDirectConversation(conversation);
      return accepts(ticket) && sequence == supportSequence;
    } catch (_) {
      if (current()) {
        supportNotice =
            'Не удалось открыть поддержку этого сервера. Повторите позже.';
      }
      return false;
    } finally {
      if (accepts(ticket) && sequence == supportSequence) {
        supportOpening = false;
        changed();
      }
    }
  }
}
