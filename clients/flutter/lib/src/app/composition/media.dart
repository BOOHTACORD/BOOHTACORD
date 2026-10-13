import 'package:flutter/foundation.dart';

import '../../core/errors/presentation.dart';
import '../../features/audio/devices/controller.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/voice/overlay/current_feed.dart';
import '../../features/voice/overlay/windows_client.dart';
import '../../features/screen/lifecycle/controller.dart';
import 'owners.dart';

void configureMedia(AppOwners app) {
  app.audioDevices = AudioDeviceController(
    scope: app.session.scope,
    readRoom: () => app.voice.room,
    readAccountId: () => app.session.user?.accountId,
    loader: app.audioDeviceLoader,
    changes: app.audioDeviceChanges,
    nativeBootstrap: app.audioDeviceBootstrap,
  )..addListener(app.notifyListeners);
  app.screen = ScreenShareController(
    app.api,
    app.session.scope,
    readRoom: () => app.voice.room,
    readAccountId: () => app.session.user?.accountId,
    voiceReady: () =>
        app.voice.voicePhase == VoicePhase.connected ||
        app.voice.voicePhase == VoicePhase.listener,
  )..addListener(app.notifyListeners);
  app.voice = VoiceController(
    app.api,
    app.session.scope,
    app.audioDevices,
    app.screen,
    readUser: () => app.session.user,
    reportError: (value) => app.error = value,
    formatError: appFailureMessage,
    roomFactory: app.voiceRoomFactory,
  )..addListener(app.notifyListeners);
  app.voiceOverlay = createCurrentVoiceOverlayFeed(
    voice: app.voice,
    roster: app.voiceRoster,
    readAccountId: () => app.session.user?.accountId,
  );
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    app.voiceOverlayWindowsClient = WindowsVoiceOverlayClient(
      feed: app.voiceOverlay,
    );
  }
}
