import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../../core/session/scope.dart';
import '../platform/driver.dart';
import 'contracts.dart';
import 'preferences.dart';

export 'contracts.dart';
export 'presentation.dart';
export 'initialization.dart';
export 'account.dart';
export 'permissions.dart';
export 'delivery.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({
    NativeNotificationDriver? driver,
    NativeNotificationPreferences? preferences,
    bool? supportedOnCurrentPlatform,
  }) : driver = driver ?? FlutterLocalNotificationDriver(),
       preferences = preferences ?? SharedPreferencesNotificationStore(),
       supportedOverride = supportedOnCurrentPlatform;
  final NativeNotificationDriver driver;
  final NativeNotificationPreferences preferences;
  final bool? supportedOverride;
  final SessionScope accountScope = SessionScope();
  SessionScope? sessionScope;
  String Function() readTitle = () => 'BOOHTACORD';
  String? accountId;
  bool initialized = false;
  Future<void>? initializing;
  bool disposed = false;
  bool enabled = false;
  NativeNotificationPermission permission =
      NativeNotificationPermission.unavailable;
  String? error;
  final Set<String> deliveriesInFlight = {};
  bool appIsForeground = true;
  bool remoteActive = false;
  bool get supported =>
      supportedOverride ??
      (!kIsWeb &&
          (Platform.isIOS ||
              Platform.isAndroid ||
              Platform.isMacOS ||
              Platform.isWindows));

  bool Function() admission() {
    final account = accountScope.capture();
    final session = sessionScope?.capture();
    return () => !disposed && account.isActive && (session?.isActive ?? true);
  }

  void changed() {
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    accountScope.dispose();
    enabled = false;
    accountId = null;
    deliveriesInFlight.clear();
    super.dispose();
  }
}
