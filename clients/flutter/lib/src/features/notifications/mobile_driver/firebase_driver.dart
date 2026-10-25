import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';
import 'contracts.dart';
import 'native_support.dart';
part 'initialize.dart';
part 'registration.dart';

@pragma('vm:entry-point')
Future<void> remoteBackgroundMessage(RemoteMessage message) async {
  // FCM/APNs owns the visible card. Never show a second local notification,
  // fetch private data, start audio, or initialize a second Firebase app here.
}

class FirebasePushDriver implements MobilePushDriver {
  FirebasePushDriver(this.configuration);
  final PushBuildConfig configuration;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _taps = StreamController<Map<String, dynamic>>.broadcast();
  final _targets = StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _initialized = false, _initialConsumed = false, _disposed = false;
  int _generation = 0;
  @override
  bool get supported =>
      mobilePushPlatform &&
      configuration.configured &&
      (platform == 'ios'
          ? const bool.fromEnvironment('NOTIFICATION_IOS_ENABLED')
          : const bool.fromEnvironment('NOTIFICATION_ANDROID_ENABLED'));
  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;
  @override
  Stream<Map<String, dynamic>> get taps => _taps.stream;
  @override
  Stream<String> get targets => _targets.stream;
  @override
  Future<PushRegistration> register({required bool askPermission}) =>
      _FirebaseRegistration(this).registerForPush(askPermission: askPermission);
  @override
  Future<void> disable({String? binding}) async {
    _generation++;
    try {
      if (_initialized && supported) {
        await FirebaseMessaging.instance
            .setAutoInitEnabled(false)
            .timeout(const Duration(seconds: 3));
        // The physical FID can serve another approved profile. Revoke the
        // scoped relay grant instead of deleting another profile's SDK route.
      }
    } finally {
      await clearCards(binding: binding).timeout(const Duration(seconds: 2));
    }
  }

  @override
  Future<void> clearCards({String? binding}) async {
    if (mobilePushPlatform) await clearRemoteCards(binding);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _messages.close();
    await _taps.close();
    await _targets.close();
  }
}
