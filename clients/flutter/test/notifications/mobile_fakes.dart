import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:boohtacord_desktop/src/features/notifications/mobile_driver/contracts.dart';
import 'package:boohtacord_desktop/src/features/notifications/mobile_driver/config.dart';
import 'package:boohtacord_desktop/src/features/notifications/mobile_enrollment/storage.dart';

final testConfig = PushBuildConfig(
  namespace: 'staging',
  relayOrigin: 'https://relay.example.invalid',
  relayPublicKey: base64Url.encode(List.filled(32, 1)).replaceAll('=', ''),
  options: const FirebaseOptions(
    apiKey: 'synthetic',
    appId: 'synthetic',
    messagingSenderId: 'synthetic',
    projectId: 'synthetic',
  ),
);
final testCapability = <String, dynamic>{
  'mobile_relay_available': true,
  'namespace': 'staging',
  'relay_origin': testConfig.relayOrigin,
  'relay_public_key': testConfig.relayPublicKey,
  'installation_signing_public_key': 'synthetic-pin',
};

class MemoryBindingStorage implements BindingStorage {
  final values = <String, Map<String, dynamic>>{};
  List<Map<String, dynamic>> revokes = [];
  @override
  Future<Map<String, dynamic>?> read(String scope) async =>
      values[scope] == null ? null : Map.of(values[scope]!);
  @override
  Future<void> write(String scope, Map<String, dynamic> value) async {
    values[scope] = Map.of(value);
  }

  @override
  Future<void> remove(String scope) async {
    values.remove(scope);
  }

  @override
  Future<List<int>> deviceSeed(String namespace) async => List.filled(32, 2);
  @override
  Future<List<Map<String, dynamic>>> pendingRevokes() async => revokes;
  @override
  Future<void> saveRevokes(List<Map<String, dynamic>> value) async {
    revokes = value;
  }
}

class FakePushDriver implements MobilePushDriver {
  final registration = Completer<PushRegistration>();
  int prompts = 0, cleared = 0;
  @override
  bool get supported => true;
  @override
  String get platform => 'android';
  @override
  Stream<Map<String, dynamic>> get messages => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get taps => const Stream.empty();
  @override
  Stream<String> get targets => const Stream.empty();
  @override
  Future<PushRegistration> register({required bool askPermission}) {
    if (askPermission) prompts++;
    return registration.future;
  }

  @override
  Future<void> clearCards({String? binding}) async {
    cleared++;
  }

  @override
  Future<void> disable({String? binding}) async {
    cleared++;
  }

  @override
  Future<void> dispose() async {}
}
