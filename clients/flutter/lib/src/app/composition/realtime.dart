import '../../features/session/lifecycle/controller.dart';
import '../../features/realtime/lifecycle/controller.dart';
import '../../features/realtime/dispatch/workspace.dart';
import '../../features/profile/state/refresh.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/notifications/message_events/controller.dart';
import '../../features/notifications/remote_lifecycle/controller.dart';
import 'owners.dart';

void configureRealtime(AppOwners app) {
  final notifications = MessageNotificationDispatch(
    app.session.scope,
    app.workspace,
    app.nativeNotifications,
    hasUser: () => app.session.user != null,
    isWelcome: (event) async {
      final page = await app.api.messagePage(
        event.payload['channel_id'] as String,
        at: event.payload['message_id'] as String,
      );
      return page.messages.any(
        (message) =>
            message.id == event.payload['message_id'] &&
            message.kind == 'SYSTEM_WELCOME' &&
            !message.deleted,
      );
    },
  );
  app.realtime = RealtimeController(
    app.api,
    app.session.scope,
    isReady: () => app.session.phase == AppPhase.ready,
    expire: app.session.expire,
    invalidatePresence: () => app.workspace.guildPresence.invalidate(),
    dispatch: WorkspaceRealtimeDispatch(
      app.workspace,
      app.conversation,
      voiceRevoked: app.voice.dispatchVoiceRevocation,
      permissionsChanged: app.permissions.refreshStrict,
      notifyMessage: notifications.call,
      notificationHint: app.remoteNotifications.realtime,
      guildChanged: app.guildProfile.refresh,
      screenViewersChanged: app.voice.screenViewerPresence.refreshFromHint,
      profileChanged: (userId, revision) async {
        if (app.session.user?.accountId == userId) {
          await app.profileOwner.refreshProfileIfNewer(revision);
        }
      },
      screenPreviewUpdated: app.voice.receiveScreenPreviewHint,
      screenPreviewInvalidated: app.voice.receiveScreenPreviewInvalidation,
    ).call,
  )..addListener(app.notifyListeners);
}
