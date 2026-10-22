import '../lifecycle/controller.dart';

extension WorkspaceSupportPublication on WorkspaceController {
  Future<void> acceptSupportPublication() async {
    final contact = supportContact;
    final ticket = scope.capture();
    if (supportConsenting ||
        !accepts(ticket) ||
        !contact.product ||
        !contact.available ||
        contact.noticeVersion < 1)
      return;
    supportConsenting = true;
    changed();
    try {
      await api.acceptSupportPublication(contact.noticeVersion);
      if (accepts(ticket)) await refreshDirectMessages();
    } catch (error) {
      if (accepts(ticket)) effects.error(effects.message(error));
    } finally {
      if (accepts(ticket)) {
        supportConsenting = false;
        changed();
      }
    }
  }
}
