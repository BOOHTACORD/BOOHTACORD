part of 'firebase_driver.dart';

extension _FirebaseInitialization on FirebasePushDriver {
  Future<void> initializeForPush() async {
    if (!supported || _disposed) throw const PushUnavailable('unavailable');
    await prepareNativePush();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: configuration.options);
    }
    final app = Firebase.app();
    if (app.options.appId != configuration.options.appId ||
        app.options.projectId != configuration.options.projectId) {
      throw const PushUnavailable('configuration');
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
    if (_initialized) return;
    FirebaseMessaging.onBackgroundMessage(remoteBackgroundMessage);
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((m) {
        if (!_disposed) _messages.add(Map.of(m.data));
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        if (!_disposed) _taps.add(Map.of(m.data));
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.instance.onRegistered.listen(
        (fid) {
          if (!_disposed) _targets.add(fid);
        },
        onError: (Object _) {
          if (!_disposed) {
            _targets.addError(
              const PushUnavailable('registration_unavailable'),
            );
          }
        },
      ),
    );
    _initialized = true;
  }
}
