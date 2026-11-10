import 'dart:async';

import '../../core/errors/presentation.dart';
import '../../features/conversation/lifecycle/controller.dart';
import '../../features/session/lifecycle/controller.dart';
import '../../features/session/reset_state/controller.dart';
import '../../features/session/maintenance_state/controller.dart';
import '../../features/realtime/lifecycle/controller.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/voice/roster_state/controller.dart';
import '../account_lifecycle/initialize.dart';
import '../account_lifecycle/clear.dart';
import 'owners.dart';

void configureSession(AppOwners app) {
  app.reset = PasswordResetController(
    app.api,
    clearError: () => app.error = null,
    message: appFailureMessage,
  )..addListener(app.notifyListeners);
  app.maintenance = MaintenanceController(app.api)
    ..addListener(app.notifyListeners);
  app.session = SessionController(
    app.api,
    startupTimeout: app.startupSessionTimeout,
    effects: SessionEffects(
      invalidateOperations: () {
        app.profileOwner.cancelOperations();
        app.workspace.cancelOperations();
        app.conversation.cancelOperations();
        app.audioDevices.cancelOperations();
        app.reset.cancelOperations();
        app.voiceRoster.stop();
      },
      resume: () async {
        final ticket = app.session.scope.capture();
        if (app.session.phase != AppPhase.ready || app.session.user == null) {
          await app.maintenance.useGuest();
          return;
        }
        unawaited(app.permissions.refresh());
        await app.realtime.close();
        if (!ticket.isActive) return;
        await app.maintenance.useAuthenticated();
        if (!ticket.isActive) return;
        app.voiceRoster.start();
        unawaited(app.realtime.connect());
      },
      initialize: app.initializePlatform,
      prepare: app.prepareAccount,
      ready: app.loadWorkspace,
      closeMedia: () => app.voice.leaveVoice(),
      closeRealtime: () => app.realtime.close(),
      clearAccount: app.clearSignedOutAccount,
      expireAccount: app.clearExpiredAccount,
      beforeServerChange: () async {
        app.conversation.loadingMessages = false;
        app.voiceRoster.stop();
        await app.maintenance.suspend();
      },
      clearServer: app.clearServerAccount,
      error: (value) => app.error = value,
      message: appFailureMessage,
    ),
  )..addListener(app.notifyListeners);
  app.nativeNotifications.sessionScope = app.session.scope;
  app.nativeNotifications.readTitle = () => app.guildProfile.name;
  app.nativeNotifications.addListener(app.notifyListeners);
  app.api.onUnauthorized = () => unawaited(app.session.expire());
}
