part of 'firebase_driver.dart';

extension _FirebaseRegistration on FirebasePushDriver {
  Future<PushRegistration> registerForPush({
    required bool askPermission,
  }) async {
    final generation = ++_generation;
    try {
      await _FirebaseInitialization(this).initializeForPush();
      if (generation != _generation || _disposed) {
        throw const PushUnavailable('cancelled');
      }
      final messaging = FirebaseMessaging.instance;
      final settings = askPermission
          ? await messaging.requestPermission(
              alert: true,
              badge: false,
              sound: true,
              provisional: false,
            )
          : await messaging.getNotificationSettings();
      final permission = switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized => PushPermission.granted,
        AuthorizationStatus.provisional => PushPermission.provisional,
        _ => PushPermission.denied,
      };
      if (permission == PushPermission.denied) {
        throw const PushUnavailable('permission_denied');
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apns;
        for (
          var attempt = 0;
          attempt < 5 && generation == _generation;
          attempt++
        ) {
          apns = await messaging.getAPNSToken();
          if (apns != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        if (apns == null) throw const PushUnavailable('apns_not_ready');
      }
      if (generation != _generation || _disposed) {
        throw const PushUnavailable('cancelled');
      }
      final target = _targets.stream.first.timeout(const Duration(seconds: 10));
      final register = Future<String>.sync(() async {
        await messaging.register();
        return '';
      });
      final responses = await Future.wait<String>([target, register])
          .timeout(const Duration(seconds: 10));
      final fid = responses.first;
      if (generation != _generation || _disposed) {
        throw const PushUnavailable('cancelled');
      }
      if (!_initialConsumed) {
        _initialConsumed = true;
        final initial = await messaging.getInitialMessage();
        if (initial != null && !_disposed) _taps.add(Map.of(initial.data));
      }
      return PushRegistration(permission, 'fcm_fid', fid);
    } on PushUnavailable {
      rethrow;
    } catch (_) {
      throw const PushUnavailable('registration_unavailable');
    }
  }
}
