import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../mobile_driver/config.dart';
import '../mobile_driver/contracts.dart';
import '../relay_auth/receipt.dart';
import '../relay_auth/signature.dart';
import '../server_preferences/api.dart';
import 'challenge_inbox.dart';
import 'relay_client.dart';
import 'storage.dart';
import 'revoke.dart';
part 'prepare.dart';
part 'pair.dart';
part 'activate.dart';

class MobileEnrollment {
  MobileEnrollment({
    required this.api,
    required this.driver,
    required this.config,
    required this.storage,
    required this.inbox,
    RelayClient? relay,
  }) : relay = relay ?? RelayClient(config);
  final NotificationApi api;
  final MobilePushDriver driver;
  final PushBuildConfig config;
  final BindingStorage storage;
  final ChallengeInbox inbox;
  final RelayClient relay;
  Future<Map<String, dynamic>> enable(
    Map<String, dynamic> capability,
    String scope,
    bool Function() active, {
    required bool askPermission,
  }) async {
    if (!config.trusts(capability) ||
        capability['mobile_relay_available'] != true) {
      throw const PushUnavailable('unavailable');
    }
    final previous = await storage.read(scope) ?? <String, dynamic>{};
    final pinned = previous['installation_key'];
    if (previous['relay_public_key'] != null &&
        previous['relay_public_key'] != config.relayPublicKey) {
      throw const PushUnavailable('installation_changed');
    }
    if (pinned != null &&
        pinned != capability['installation_signing_public_key']) {
      throw const PushUnavailable('installation_changed');
    }
    await reconcileRevokes(storage, relay, config);
    if (!active()) throw const PushUnavailable('cancelled');
    final registration = await driver.register(askPermission: askPermission);
    if (!active()) throw const PushUnavailable('cancelled');
    final targetHash = sha256
        .convert(
          utf8.encode('${registration.targetKind}\x00${registration.target}'),
        )
        .toString();
    final expires = DateTime.tryParse(previous['expires_at'] as String? ?? '');
    if (previous['phase'] == 'active' &&
        previous['target_hash'] == targetHash &&
        expires != null &&
        expires.isAfter(DateTime.now().toUtc().add(const Duration(days: 7)))) {
      return previous;
    }
    final seed = await storage.deviceSeed(config.namespace);
    final public = base64Url
        .encode(await relayPublicKey(seed))
        .replaceAll('=', '');
    Map<String, dynamic> cached = {
      ...previous,
      'installation_key': capability['installation_signing_public_key'],
      'consent': true,
      'relay_public_key': config.relayPublicKey,
      'relay_origin': config.relayOrigin,
      'namespace': config.namespace,
      'target_hash': targetHash,
    };
    if (!preparationExpired(cached) &&
        cached['phase'] == 'pending_activation' &&
        cached['receipt'] is Map<String, dynamic>) {
      return _activate(cached, scope, active);
    }
    final prepared = await prepare(cached, scope, active, registration);
    cached = await storage.read(scope) ?? cached;
    if (!active()) throw const PushUnavailable('cancelled');
    return pair(
      capability,
      cached,
      prepared,
      scope,
      active,
      seed,
      public,
      registration,
    );
  }

  void close() => relay.close();
}
