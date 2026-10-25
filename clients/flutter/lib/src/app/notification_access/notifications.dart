import '../../services/native_notifications.dart';
import '../../features/notifications/remote_lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppNotificationsAccess on AppOwners {
  bool get notificationsSupported => nativeNotifications.supported;

  bool get notificationsEnabled => nativeNotifications.enabled;

  NativeNotificationPermission get notificationPermission =>
      nativeNotifications.permission;

  String? get notificationError => nativeNotifications.error;

  Future<void> enableNotifications() async {
    await nativeNotifications.enable();
  }

  Future<void> disableNotifications() => nativeNotifications.disable();

  Future<void> refreshNotificationStatus() =>
      nativeNotifications.refreshStatus();

  void setNotificationAppForeground(bool foreground) {
    nativeNotifications.appIsForeground = foreground;
    remoteNotifications.setForeground(foreground);
  }
}
