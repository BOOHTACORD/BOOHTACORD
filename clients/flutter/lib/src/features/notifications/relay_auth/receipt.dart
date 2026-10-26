import 'dart:convert';

import '../remote_payload/utc.dart';

import 'package:cryptography/cryptography.dart';

List<int> relayDecode(String value, int length) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw const FormatException('Invalid relay receipt');
  }
  final raw = base64Url.decode(base64Url.normalize(value));
  if (raw.length != length ||
      base64Url.encode(raw).replaceAll('=', '') != value) {
    throw const FormatException('Invalid relay receipt');
  }
  return raw;
}

Future<Map<String, dynamic>> verifyRelayReceipt(
  Map<String, dynamic> receipt, {
  required String publicKey,
  required Map<String, dynamic> capability,
  required String binding,
  required int generation,
  required String nonce,
  required DateTime now,
}) async {
  const failure = FormatException('Invalid relay receipt');
  if (receipt.length != 2 ||
      receipt['payload'] is! String ||
      receipt['signature'] is! String) {
    throw failure;
  }
  final text = receipt['payload'] as String;
  if (text.length > 8192 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(text)) {
    throw failure;
  }
  final payload = base64Url.decode(base64Url.normalize(text));
  if (base64Url.encode(payload).replaceAll('=', '') != text) throw failure;
  final key = SimplePublicKey(
    relayDecode(publicKey, 32),
    type: KeyPairType.ed25519,
  );
  final signature = Signature(
    relayDecode(receipt['signature'], 64),
    publicKey: key,
  );
  if (!await Ed25519().verify([
    ...utf8.encode('notification-relay-grant/v1\x00'),
    ...payload,
  ], signature: signature)) {
    throw failure;
  }
  final value = jsonDecode(utf8.decode(payload));
  if (value is! Map<String, dynamic>) throw failure;
  const fields = {
    'version',
    'grant_id',
    'tenant_id',
    'origin',
    'installation_id',
    'installation_public_key',
    'binding_id',
    'generation',
    'namespace',
    'nonce',
    'expires_at',
  };
  if (value.length != fields.length ||
      !fields.containsAll(value.keys) ||
      value['version'] != 1) {
    throw failure;
  }
  final uuid = RegExp(
    r'^(?!00000000-0000-0000-0000-000000000000$)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  for (final name in [
    'grant_id',
    'tenant_id',
    'installation_id',
    'binding_id',
  ]) {
    if (value[name] is! String || !uuid.hasMatch(value[name])) throw failure;
  }
  if (value['origin'] != capability['origin'] ||
      value['installation_id'] != capability['installation_id'] ||
      value['installation_public_key'] !=
          capability['installation_signing_public_key'] ||
      value['binding_id'] != binding ||
      value['generation'] != generation ||
      value['namespace'] != capability['namespace'] ||
      value['nonce'] != nonce) {
    throw failure;
  }
  relayDecode(value['installation_public_key'], 32);
  relayDecode(value['nonce'], 32);
  final expiry = value['expires_at'];
  if (expiry is! String || !RegExp(r'(Z|[+]00:00)$').hasMatch(expiry)) {
    throw failure;
  }
  final until = notificationUtc(expiry);
  if (until == null ||
      !until.isAfter(now) ||
      until.difference(now) > const Duration(days: 180)) {
    throw failure;
  }
  return value;
}
