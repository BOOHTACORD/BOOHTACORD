import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'canonical.dart';

Future<Map<String, String>> signRelayHeaders({
  required List<int> seed,
  required String role,
  required String subject,
  required String method,
  required String path,
  required List<int> body,
  required DateTime now,
  required String nonce,
}) async {
  _validateSeed(seed);
  final ts = _formatTimestamp(now.toUtc());
  final canonical = relayCanonical(
    role: role,
    subject: subject,
    method: method,
    path: path,
    timestamp: ts,
    nonce: nonce,
    body: body,
  );
  final keyPair = await Ed25519().newKeyPairFromSeed(seed);
  final sig = await Ed25519().sign(canonical, keyPair: keyPair);
  return {
    'Content-Type': 'application/json',
    'X-Relay-Role': role,
    'X-Relay-Subject': subject,
    'X-Relay-Timestamp': ts,
    'X-Relay-Nonce': nonce,
    'X-Relay-Signature': base64Url.encode(sig.bytes).replaceAll('=', ''),
  };
}

Future<List<int>> relayPublicKey(List<int> seed) async {
  _validateSeed(seed);
  final keyPair = await Ed25519().newKeyPairFromSeed(seed);
  return (await keyPair.extractPublicKey()).bytes;
}

void _validateSeed(List<int> seed) {
  if (seed.length != 32) throw const FormatException('invalid');
  for (final b in seed) {
    if (b < 0 || b > 255) throw const FormatException('invalid');
  }
}

String _formatTimestamp(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}Z';
}
