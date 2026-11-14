export const voiceLeaseRevocationReasons = [
  'TRANSFER', 'KICK', 'CHANNEL_CLOSED', 'SESSION_REVOKED', 'BANNED', 'LOGOUT', 'VOLUNTARY_LEAVE', 'AFK_MOVE',
] as const

export type VoiceLeaseRevocationReason = typeof voiceLeaseRevocationReasons[number]

export function isVoiceLeaseRevocationReason(value: unknown): value is VoiceLeaseRevocationReason {
  return typeof value === 'string' && voiceLeaseRevocationReasons.some((reason) => reason === value)
}

export function voiceLeaseRevocationMessage(reason: VoiceLeaseRevocationReason): string {
  switch (reason) {
    case 'TRANSFER': return 'Голосовое подключение перенесено.'
    case 'KICK': return 'Администратор отключил вас от голосового канала.'
    case 'CHANNEL_CLOSED': return 'Голосовой канал закрыт администратором.'
    case 'SESSION_REVOKED': return 'Сессия отозвана; голосовое подключение завершено.'
    case 'BANNED': return 'Доступ к гильдии отозван; голосовое подключение завершено.'
    case 'LOGOUT': return 'Сеанс завершён; голосовое подключение остановлено.'
    case 'VOLUNTARY_LEAVE': return 'Голосовое подключение завершено.'
    case 'AFK_MOVE': return 'Вы перемещены в AFK-канал из-за неактивности.'
  }
}
