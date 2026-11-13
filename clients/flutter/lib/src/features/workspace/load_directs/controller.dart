import '../../../models.dart';
import '../../direct/conversations/support_contact.dart';
import '../lifecycle/controller.dart';

final _realtimeLoads = Expando<int>();

extension WorkspaceDirects on WorkspaceController {
  Future<void> refreshDirectMessages({bool strict = false}) async {
    final sequence = ++directNavigationSequence;
    _realtimeLoads[this] = strict ? sequence : null;
    final owner = api.transport.session.telemetry.snapshot();
    final ticket = scope.capture();
    if (!accepts(ticket)) return;
    try {
      final result = await api.directMessages();
      if (!accepts(ticket) || sequence != directNavigationSequence) return;
      if (!api.transport.session.telemetry.current(owner)) {
        supportContact = const SupportContact(state: 'unavailable');
        changed();
        return;
      }
      final contact = result is DirectNavigation
          ? result.support
          : const SupportContact();
      if (supportContact.accountId != null &&
          contact.available &&
          supportContact.accountId != contact.accountId) {
        supportChanged = true;
      }
      supportContact = contact;
      directMessages = result;
      if (navigationSection == NavigationSection.directMessages) {
        final candidates = await api.directMessageCandidates();
        if (!accepts(ticket) || sequence != directNavigationSequence) return;
        directMessageCandidates = candidates;
      }
    } catch (cause) {
      if (strict && accepts(ticket) && sequence == directNavigationSequence) rethrow;
      if (accepts(ticket) && sequence == directNavigationSequence) {
        supportContact = supportContact.unavailable;
        effects.error(effects.message(cause));
      }
    } finally {
      if (_realtimeLoads[this] == sequence) _realtimeLoads[this] = null;
    }
    if (accepts(ticket) && sequence == directNavigationSequence) changed();
  }

  void invalidateRealtimeDirects() {
    if (_realtimeLoads[this] == directNavigationSequence) directNavigationSequence++;
    _realtimeLoads[this] = null;
  }

  Future<void> createDirectConversation(DirectCandidate candidate) async {
    final ticket = scope.capture();
    if (!accepts(ticket)) return;
    try {
      final id = await api.openDirectMessage(candidate.id);
      if (!accepts(ticket)) return;
      await refreshDirectMessages();
      if (!accepts(ticket)) return;
      final conversation = directMessages
          .where((value) => value.id == id)
          .firstOrNull;
      if (conversation != null) await openDirectConversation(conversation);
    } catch (cause) {
      if (accepts(ticket)) {
        effects.error(effects.message(cause));
        changed();
      }
    }
  }
}
