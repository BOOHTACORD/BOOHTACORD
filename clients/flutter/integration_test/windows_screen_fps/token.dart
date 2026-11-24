import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:livekit_client/livekit_client.dart';
// ignore: depend_on_referenced_packages
import 'package:logging/logging.dart';

void configureOwnedFpsSfu(String url) {
  if (Uri.parse(url).host != '127.0.0.1') {
    throw StateError('Only an owned loopback SFU is allowed');
  }
  hierarchicalLoggingEnabled = true;
  setLoggingLevel(LoggerLevel.kOFF);
}

// Synthetic credentials belong only to the disposable loopback SFU.
String ownedFpsToken(String identity) {
  String b64(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload =
      '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({
        'iss': 'fpsdevkey',
        'sub': identity,
        'nbf': now - 5,
        'exp': now + 600,
        'video': {'roomJoin': true, 'room': 'fps-owned', 'canPublish': true, 'canSubscribe': true, 'canUpdateOwnMetadata': true},
      })}';
  final key = utf8.encode('fps-local-disposable-01234567890123456789');
  final sig = Hmac(sha256, key).convert(utf8.encode(payload));
  return '$payload.${base64Url.encode(sig.bytes).replaceAll('=', '')}';
}
