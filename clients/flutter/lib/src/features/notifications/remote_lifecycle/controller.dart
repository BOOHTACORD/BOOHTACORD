import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/http/transport.dart';
import '../lifecycle/controller.dart';
import '../mobile_driver/config.dart';
import '../mobile_driver/contracts.dart';
import '../mobile_driver/firebase_driver.dart';
import '../mobile_enrollment/challenge_inbox.dart';
import '../mobile_enrollment/enroll.dart';
import '../mobile_enrollment/revoke.dart';
import '../mobile_enrollment/storage.dart';
import '../remote_payload/envelope.dart';
import '../remote_payload/dedup.dart';
import '../server_preferences/api.dart';
import '../server_preferences/client.dart';
import '../server_preferences/controller.dart';
part 'start.dart';
part 'enable.dart';
part 'registration_guard.dart';
part 'clear.dart';
part 'events.dart';
part 'attention.dart';

class RemoteNotificationController extends ChangeNotifier {
  RemoteNotificationController(
    this.transport,
    this.local, {
    PushBuildConfig? config,
    MobilePushDriver? driver,
    BindingStorage? storage,
  }) : config = config ?? PushBuildConfig.environment(),
       driver =
           driver ??
           FirebasePushDriver(config ?? PushBuildConfig.environment()),
       storage = storage ?? SecureBindingStorage() {
    subscriptions.add(
      this.driver.messages.listen(packet, onError: (Object _) {}),
    );
    subscriptions.add(
      this.driver.taps.listen(
        (data) => packet(data, tap: true),
        onError: (Object _) {},
      ),
    );
    subscriptions.add(
      this.driver.targets.listen((_) {
        if (foreground && activeDevice && !busy) {
          unawaited(enable(askPermission: false));
        }
      }, onError: (Object _) {}),
    );
  }
  final ApiTransport transport;
  final NotificationController local;
  final PushBuildConfig config;
  final MobilePushDriver driver;
  final BindingStorage storage;
  final inbox = ChallengeInbox();
  final subscriptions = <StreamSubscription<dynamic>>[];
  NotificationApi? api;
  NotificationPreferencesController? preferences;
  MobileEnrollment? enrollment;
  Map<String, dynamic>? capability, binding;
  List<Map<String, dynamic>> devices = [];
  String? account, scope, error;
  String status = 'Не включено на этом устройстве', hint = '';
  bool busy = false, disposed = false, foreground = true;
  int epoch = 0, operation = 0;
  Timer? attentionTimer;
  final viewId = const Uuid().v4();
  Map<String, String>? Function()? visibleConversation;
  Future<void> Function(Map<String, dynamic>)? navigate;
  bool Function()? canNavigate;
  String? lastAttention;
  DateTime? lastAttentionAt;
  NotificationEnvelope? pendingTap;
  final Set<String> handledTaps = {};
  bool get activeDevice => local.remoteActive;
  bool get available =>
      capability?['mobile_relay_available'] == true &&
      driver.supported &&
      config.trusts(capability!);
  void changed() {
    if (!disposed) notifyListeners();
  }

  bool current(int value) => !disposed && epoch == value && account != null;
  @override
  void dispose() {
    disposed = true;
    epoch++;
    operation++;
    attentionTimer?.cancel();
    inbox.clear();
    enrollment?.close();
    preferences?.dispose();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(driver.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
