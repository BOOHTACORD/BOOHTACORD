part of 'controller.dart';

extension RemoteNotificationAttention on RemoteNotificationController {
  Future<void> attention() async {
    final visible = visibleConversation?.call(), port = api;
    if (port == null || visible == null || preferences?.snapshot == null) {
      return;
    }
    try {
      await port.checked('PUT', '/notification-attention', {
        'view_id': viewId,
        'kind': visible['kind'],
        'conversation_id': visible['conversation_id'],
        'visible': foreground,
      });
    } catch (_) {}
  }

  void setForeground(bool value) {
    foreground = value;
    unawaited(attention());
  }

  void contextChanged() {
    final value = visibleConversation?.call();
    final key = jsonEncode([value, foreground]);
    final now = DateTime.now();
    if (key == lastAttention &&
        lastAttentionAt != null &&
        now.difference(lastAttentionAt!) < const Duration(seconds: 15)) {
      return;
    }
    lastAttention = key;
    lastAttentionAt = now;
    unawaited(attention());
  }
}
