import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';

class PushBuildConfig {
  const PushBuildConfig({
    required this.namespace,
    required this.relayOrigin,
    required this.relayPublicKey,
    required this.options,
  });
  final String namespace, relayOrigin, relayPublicKey;
  final FirebaseOptions options;
  factory PushBuildConfig.environment() => const PushBuildConfig(
    namespace: String.fromEnvironment('NOTIFICATION_NAMESPACE'),
    relayOrigin: String.fromEnvironment('NOTIFICATION_RELAY_ORIGIN'),
    relayPublicKey: String.fromEnvironment('NOTIFICATION_RELAY_PUBLIC_KEY'),
    options: FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      iosBundleId: 'ru.boohtacord.app',
    ),
  );
  bool get configured {
    final uri = Uri.tryParse(relayOrigin);
    if (!['staging', 'production'].contains(namespace) ||
        uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.origin != relayOrigin ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    try {
      if (base64Url.decode(base64Url.normalize(relayPublicKey)).length != 32) {
        return false;
      }
    } catch (_) {
      return false;
    }
    return options.apiKey.isNotEmpty &&
        options.appId.isNotEmpty &&
        options.messagingSenderId.isNotEmpty &&
        options.projectId.isNotEmpty;
  }

  bool trusts(Map<String, dynamic> capability) =>
      configured &&
      capability['namespace'] == namespace &&
      capability['relay_origin'] == relayOrigin &&
      capability['relay_public_key'] == relayPublicKey;
}
