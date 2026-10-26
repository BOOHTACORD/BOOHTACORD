import '../../services/native_notifications.dart';
import '../../features/notifications/remote_lifecycle/controller.dart';
import '../../features/conversation/lifecycle/controller.dart';
import '../../features/realtime/lifecycle/controller.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/voice/preferences/clear.dart';
import '../../features/voice/roster_state/controller.dart';
import '../composition/owners.dart';
import '../media_preferences/screen.dart';

extension AppAccountCleanup on AppOwners {
  void clearPrivateCaches() {
    permissions.stop();
    profileOwner.clear();
    workspace.clear();
    conversation.clear();
    voiceRoster.stop();
    voiceRoster.voiceRosters = null;
    voiceRoster.voiceRosterError = null;
    voice.clearAccountPreferences();
    resetScreenPreference();
    voiceOverlayPreferences = null;
    voiceOverlay.setEnabled(false);
    voiceOverlay.setOnlySpeakers(false);
    voiceOverlay.setMaxParticipants(8);
    voiceOverlayWindowsClient?.configuration.clearAccount();
    voiceOverlaySettingsRevision++;
    audioDevices.clearAccount();
  }

  Future<void> clearSignedOutAccount() async {
    clearPrivateCaches();
    await remoteNotifications.stop();
    await nativeNotifications.useAccount(null);
  }

  Future<void> clearServerAccount() async {
    await clearSignedOutAccount();
    maintenance.restart();
  }

  Future<void> clearExpiredAccount() async {
    final ticket = session.scope.capture();
    final leaving = voice.leaveVoice();
    clearPrivateCaches();
    error = null;
    session.logoutError = null;
    realtime.delivery.reset();
    notifyListeners();
    await Future.wait([
      leaving,
      realtime.close(),
      nativeNotifications.useAccount(null),
      remoteNotifications.stop(),
    ]);
    if (!ticket.isCurrent) return;
    error = null;
    notifyListeners();
  }
}
