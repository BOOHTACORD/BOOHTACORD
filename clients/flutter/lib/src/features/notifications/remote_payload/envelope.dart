import 'dart:convert';

import 'utc.dart';

/// Immutable, fully-validated notification envelope (schema v1).
class NotificationEnvelope {
  final int version;
  final int generation;
  final String bindingRef;
  final String notificationRef;
  final String groupRef;
  final String template;
  final DateTime expiresAt;

  const NotificationEnvelope._({
    required this.version,
    required this.generation,
    required this.bindingRef,
    required this.notificationRef,
    required this.groupRef,
    required this.template,
    required this.expiresAt,
  });

  static final Set<String> _templates = {
    'direct_message',
    'mention',
    'activity',
  };
  static final RegExp _refPattern = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

  /// Neutral fixed Russian title per template.
  String get title {
    switch (template) {
      case 'direct_message':
        return 'Новое сообщение';
      case 'mention':
        return 'Вас упомянули';
      default:
        return 'Активность';
    }
  }

  /// Parses a decoded JSON object. Returns null on any validation failure.
  static NotificationEnvelope? parse(Object? input, DateTime now) {
    if (input is! Map<String, dynamic>) return null;
    final keys = input.keys.toSet();
    const expected = {
      'version',
      'generation',
      'binding_ref',
      'notification_ref',
      'template',
      'expires_at',
      'group_ref',
    };
    if (keys.length != 7 || !expected.containsAll(keys)) return null;

    final v = input['version'];
    if (v is! int || v != 1) return null;

    final g = input['generation'];
    if (g is! int || g < 1 || g > 1000000000) return null;

    final br = input['binding_ref'];
    final nr = input['notification_ref'];
    final gr = input['group_ref'];
    if (br is! String || !_refPattern.hasMatch(br)) return null;
    if (nr is! String || !_refPattern.hasMatch(nr)) return null;
    if (gr is! String || !_refPattern.hasMatch(gr)) return null;

    final t = input['template'];
    if (t is! String || !_templates.contains(t)) return null;

    final ea = input['expires_at'];
    if (ea is! String || !RegExp(r'(Z|[+]00:00)$').hasMatch(ea)) return null;
    final exp = notificationUtc(ea);
    if (exp == null) return null;
    if (!exp.isUtc) return null;
    if (!exp.isAfter(now)) return null;
    if (exp.difference(now) > const Duration(hours: 24)) return null;

    return NotificationEnvelope._(
      version: v,
      generation: g,
      bindingRef: br,
      notificationRef: nr,
      groupRef: gr,
      template: t,
      expiresAt: exp,
    );
  }

  /// Accepts a provider payload map with a single 'boohtacord' string field.
  static NotificationEnvelope? fromProvider(
    Map<String, dynamic> data,
    DateTime now,
  ) {
    if (data.length != 1 || !data.containsKey('boohtacord')) return null;
    final raw = data['boohtacord'];
    if (raw is! String || raw.isEmpty || raw.length > 4096) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    return parse(decoded, now);
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'generation': generation,
    'binding_ref': bindingRef,
    'notification_ref': notificationRef,
    'group_ref': groupRef,
    'template': template,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };
}
