void setConversationNotificationRule(
  Map<String, dynamic> settings,
  String kind,
  String id,
  String mode,
  String? pause,
) {
  settings['overrides'] = [
    ...(settings['overrides'] as List).where(
      (o) => o['kind'] != kind || o['id'] != id,
    ),
    {'kind': kind, 'id': id, 'mode': mode, 'paused_until': pause},
  ];
}

void resetConversationNotificationRule(
  Map<String, dynamic> settings,
  String kind,
  String id,
) {
  settings['overrides'] = (settings['overrides'] as List)
      .where((o) => o['kind'] != kind || o['id'] != id)
      .toList();
}
