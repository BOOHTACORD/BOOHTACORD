import 'dart:async';

import 'owners.dart';

void disposeOwners(AppOwners app) {
  app.disposed = true;
  app.guildProfile.dispose();
  app.api.onUnauthorized = null;
  app.session.dispose();
  app.realtime.dispose();
  app.voiceRoster.dispose();
  app.profileOwner.dispose();
  app.workspace.dispose();
  app.conversation.dispose();
  app.nativeNotifications.dispose();
  app.remoteNotifications.dispose();
  app.maintenance.dispose();
  app.reset.dispose();
  unawaited(app.voiceOverlayWindowsClient?.dispose() ?? Future<void>.value());
  app.voiceOverlay.dispose();
  app.voice.dispose();
  app.screen.dispose();
  app.audioDevices.dispose();
  app.permissions.dispose();
}
