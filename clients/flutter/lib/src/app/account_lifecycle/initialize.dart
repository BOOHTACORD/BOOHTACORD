import 'dart:async';

import '../../models.dart';
import '../../services/native_notifications.dart';
import '../../features/notifications/remote_lifecycle/controller.dart';
import '../../features/session/lifecycle/controller.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../../features/profile/state/controller.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/voice/roster_state/controller.dart';
import '../../features/realtime/lifecycle/controller.dart';
import '../composition/owners.dart';
import '../../features/voice/overlay/preferences.dart';
import '../media_preferences/screen.dart';
import '../overlay_preferences/actions.dart';

extension AppAccountInitialization on AppOwners {
  Future<void> initializePlatform() async {
    final ticket = session.scope.capture();
    await voice.loadVoiceStreamSoundPreference();
    await voice.loadVoiceRoomEventSoundPreference();
    if (!ticket.isActive) return;
    await nativeNotifications.initialize();
    if (!ticket.isActive) return;
    maintenance.start();
  }

  Future<void> prepareAccount(SessionUser account) async {
    final ticket = session.scope.capture();
    await nativeNotifications.useAccount(account.accountId);
    if (!ticket.isActive) return;
    if (voiceOverlayWindowsClient != null) {
      final overlayPreferences = await VoiceOverlayPreferences.open(
        account.accountId,
      );
      if (!ticket.isActive || session.user?.accountId != account.accountId) {
        return;
      }
      voiceOverlayPreferences = overlayPreferences;
      voiceOverlay.setOnlySpeakers(overlayPreferences.onlySpeakers);
      bindOverlayPlacement();
      await saveOverlayConfiguration(overlayPreferences.configuration);
      if (!ticket.isActive) return;
    }
    await restoreScreenPreferences();
    if (!ticket.isActive || session.user?.accountId != account.accountId) {
      return;
    }
    await voice.loadAudioPreferences(account.accountId);
    if (!ticket.isActive || audioDevices.nativeBootstrap == null) return;
    // macOS creates its AudioEngine device module lazily. Bootstrap it after
    // the account is known, before the workspace or voice join can request a
    // device, so the settings screen starts with the complete inventory.
    await audioDevices.bootstrap();
  }

  Future<void> loadWorkspace() async {
    final ticket = session.scope.capture();
    await Future.wait([
      permissions.start(),
      workspace.refreshTopology(),
      workspace.refreshMembers(),
      workspace.refreshDirectMessages(),
      profileOwner.refreshProfile(),
    ]);
    if (!ticket.isActive || session.phase != AppPhase.ready) return;
    voiceRoster.start();
    unawaited(remoteNotifications.start(session.user!.accountId));
    unawaited(realtime.connect());
  }
}
