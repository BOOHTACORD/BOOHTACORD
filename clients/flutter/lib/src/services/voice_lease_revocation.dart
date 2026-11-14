class VoiceLeaseRevocation {
  const VoiceLeaseRevocation({required this.leaseId, required this.reason});

  final String leaseId;
  final String reason;

  static VoiceLeaseRevocation? parse(
    Object? leaseId,
    Object? reason, {
    required String? activeLeaseId,
    required bool admissionPending,
  }) {
    const knownReasons = {
      'TRANSFER',
      'KICK',
      'CHANNEL_CLOSED',
      'SESSION_REVOKED',
      'BANNED',
      'LOGOUT',
      'VOLUNTARY_LEAVE',
      'AFK_MOVE',
    };
    if (leaseId is! String ||
        reason is! String ||
        !knownReasons.contains(reason)) {
      return null;
    }
    if (!admissionPending && leaseId != activeLeaseId) return null;
    return VoiceLeaseRevocation(leaseId: leaseId, reason: reason);
  }

  String get message => switch (reason) {
    'TRANSFER' => 'Голосовое подключение перенесено.',
    'KICK' => 'Администратор отключил вас от голосового канала.',
    'CHANNEL_CLOSED' => 'Голосовой канал закрыт администратором.',
    'SESSION_REVOKED' => 'Сессия отозвана; голосовое подключение завершено.',
    'BANNED' => 'Доступ к гильдии отозван; голосовое подключение завершено.',
    'LOGOUT' => 'Сеанс завершён; голосовое подключение остановлено.',
    'AFK_MOVE' => 'Вы перемещены в AFK-канал из-за неактивности.',
    _ => 'Голосовое подключение завершено.',
  };
}
