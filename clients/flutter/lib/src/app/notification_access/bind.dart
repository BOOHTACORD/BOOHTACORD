import 'dart:async';

import 'target.dart';
import '../../models.dart';
import '../../features/notifications/remote_lifecycle/controller.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../../features/session/lifecycle/controller.dart';
import '../composition/owners.dart';

void configureNotifications(AppOwners app) {
  app.remoteNotifications = RemoteNotificationController(
    app.api.transport,
    app.nativeNotifications,
  )..addListener(app.notifyListeners);
  app.remoteNotifications.visibleConversation = () {
    if (app.session.phase != AppPhase.ready ||
        app.workspace.workspacePanel != WorkspacePanel.none) {
      return null;
    }
    final direct = app.workspace.selectedDirectMessage;
    if (direct != null) {
      return {'kind': 'DIRECT_MESSAGE', 'conversation_id': direct.id};
    }
    final channel = app.workspace.selectedChannel;
    if (channel?.kind == ChannelKind.text) {
      return {'kind': 'CHANNEL', 'conversation_id': channel!.id};
    }
    return null;
  };
  app.remoteNotifications.canNavigate = () =>
      app.workspace.workspacePanel == WorkspacePanel.none;
  app.remoteNotifications.navigate = (target) async {
    if (app.session.phase != AppPhase.ready || target['version'] != 1) return;
    final version = app.remoteNotifications.epoch;
    final message = await resolveNotificationMessage(app.api, target);
    if (message == null) throw StateError('Notification message unavailable');
    if (app.remoteNotifications.current(version) &&
        app.workspace.workspacePanel == WorkspacePanel.none) {
      await app.workspace.openSearchContext(
        message,
        heading: 'Сообщение из уведомления',
      );
    }
  };
  var lastCanNavigate = app.remoteNotifications.canNavigate!();
  app.addListener(() {
    if (!app.disposed) {
      final can = app.remoteNotifications.canNavigate!();
      final open = can && !lastCanNavigate;
      lastCanNavigate = can;
      app.remoteNotifications.contextChanged();
      if (open && app.remoteNotifications.pendingTap != null) {
        unawaited(app.remoteNotifications.openPending());
      }
    }
  });
}
