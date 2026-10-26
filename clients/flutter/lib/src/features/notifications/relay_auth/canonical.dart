import 'dart:convert';

import 'package:crypto/crypto.dart';

const int _maxField = 256;
const int _maxBody = 16384;

final RegExp _pathRe = RegExp(r'^/v1/[a-z0-9_/-]+$');

List<int> relayCanonical({
  required String role,
  required String subject,
  required String method,
  required String path,
  required String timestamp,
  required String nonce,
  required List<int> body,
}) {
  if (role != 'tenant' && role != 'device') {
    throw const FormatException('invalid');
  }
  if (method != 'POST' &&
      method != 'GET' &&
      method != 'DELETE' &&
      method != 'PUT') {
    throw const FormatException('invalid');
  }
  if (path.length > _maxField ||
      !_pathRe.hasMatch(path) ||
      path.contains('//')) {
    throw const FormatException('invalid');
  }
  for (final c in path.codeUnits) {
    if (c < 0x21 || c > 0x7e) throw const FormatException('invalid');
  }
  final sub = _canonicalUuid(subject);
  final non = _canonicalUuid(nonce);
  final ts = _canonicalTimestamp(timestamp);
  if (body.length > _maxBody) throw const FormatException('invalid');
  for (final b in body) {
    if (b < 0 || b > 255) throw const FormatException('invalid');
  }
  final hex = sha256.convert(body).toString();
  return utf8.encode(
    [
      'notification-relay-request/v1',
      role,
      sub,
      method,
      path,
      ts,
      non,
      hex,
    ].join('\n'),
  );
}

String _canonicalUuid(String s) {
  if (s.length > _maxField) throw const FormatException('invalid');
  final m = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).firstMatch(s);
  if (m == null) throw const FormatException('invalid');
  final v = s.toLowerCase();
  if (v == '00000000-0000-0000-0000-000000000000') {
    throw const FormatException('invalid');
  }
  return v;
}

String _canonicalTimestamp(String s) {
  if (s.length > _maxField) throw const FormatException('invalid');
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$')
      .firstMatch(s);
  if (m == null) throw const FormatException('invalid');
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final h = int.parse(m.group(4)!);
  final mi = int.parse(m.group(5)!);
  final se = int.parse(m.group(6)!);
  if (mo < 1 || mo > 12) throw const FormatException('invalid');
  final daysInMonth = [
    31,
    _leap(y) ? 29 : 28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ][mo - 1];
  if (d < 1 || d > daysInMonth) throw const FormatException('invalid');
  if (h > 23 || mi > 59 || se > 59) throw const FormatException('invalid');
  return s;
}

bool _leap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
