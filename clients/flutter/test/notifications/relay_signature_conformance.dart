import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/features/notifications/relay_auth/canonical.dart';
import 'package:boohtacord_desktop/src/features/notifications/relay_auth/signature.dart';

void check(bool value, String reason) {
  if (!value) throw StateError(reason);
}

Future<void> main() async {
  final fixture = jsonDecode(
    await File.fromUri(
      Platform.script.resolve(
        '../../../../contracts/notification-relay-signature-v1.fixtures.json',
      ),
    ).readAsString(),
  ) as Map<String, dynamic>;
  final seed = <int>[
    for (var i = 0; i < 64; i += 2)
      int.parse(
        (fixture['test_seed_hex'] as String).substring(i, i + 2),
        radix: 16,
      ),
  ];
  final body = base64Url.decode(
    base64Url.normalize(fixture['body_base64'] as String),
  );
  final canonical = relayCanonical(
    role: fixture['role'],
    subject: fixture['subject'],
    method: fixture['method'],
    path: fixture['path'],
    timestamp: fixture['timestamp'],
    nonce: fixture['nonce'],
    body: body,
  );
  check(
    base64Url.encode(canonical).replaceAll('=', '') ==
        fixture['canonical_base64'],
    'Go/Dart canonical bytes differ',
  );
  final headers = await signRelayHeaders(
    seed: seed,
    role: fixture['role'],
    subject: fixture['subject'],
    method: fixture['method'],
    path: fixture['path'],
    body: body,
    now: DateTime.parse(fixture['timestamp']),
    nonce: fixture['nonce'],
  );
  check(
    headers['X-Relay-Signature'] == fixture['signature'],
    'Go/Dart Ed25519 signatures differ',
  );
  check(
    base64Url.encode(await relayPublicKey(seed)).replaceAll('=', '') ==
        fixture['public_key'],
    'Go/Dart public keys differ',
  );
  for (final path in [
    '/v1//grants',
    '/v1/grants?token=x',
    '/v1/%2fgrants',
    '/v1/../grants',
  ]) {
    var rejected = false;
    try {
      relayCanonical(
        role: 'device',
        subject: fixture['subject'],
        method: 'POST',
        path: path,
        timestamp: fixture['timestamp'],
        nonce: fixture['nonce'],
        body: body,
      );
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'Ambiguous path accepted');
  }
  stdout.writeln(
    'PASS: Go/Dart signature interoperability and malformed-path guards',
  );
}
