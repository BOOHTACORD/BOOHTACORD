import type { ScreenShareDescriptorV1 } from './types'

export type ScreenProfileSource = 'sender-metadata' | 'legacy-track-name' | 'unknown'

export function screenTargetLabel(profileId?: string, legacyTarget?: string): string {
  const match = /^P(720|1080|1440)_(15|30|60)$/.exec(profileId ?? '')
  return match ? `${match[1]}p · ${match[2]} FPS` : legacyTarget ?? 'Нет данных от источника'
}

export function screenTargetSourceLabel(source: ScreenProfileSource | undefined): string {
  if (source === 'sender-metadata') return 'Цель передана отправителем'
  if (source === 'legacy-track-name') return 'Профиль при запуске · имя дорожки'
  return 'Цель не передана отправителем'
}

export function screenModeLabel(mode: ScreenShareDescriptorV1['mode'] | undefined): string {
  return mode === 'motion' ? 'Плавность' : mode === 'text' ? 'Текст' : 'Нет данных от отправителя'
}

export function screenCaptureLabel(descriptor?: ScreenShareDescriptorV1): string {
  if (!descriptor) return 'Нет данных от отправителя'
  const capture = descriptor.effective_profile.capture
  return `${capture.max_width} × ${capture.max_height} пикс. · до ${capture.max_fps} FPS`
}

export function screenEncodingLabel(descriptor?: ScreenShareDescriptorV1): string {
  if (!descriptor) return 'Нет данных от отправителя'
  return descriptor.effective_profile.encoding.layers.map((layer, index) => {
    const bitrate = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 }).format(layer.max_bitrate_bps / 1_000_000)
    return `${index + 1}: ${layer.width} × ${layer.height}, до ${layer.max_fps} FPS и ${bitrate} Мбит/с`
  }).join(' · ')
}

export function screenDescriptorStatusLabel(descriptor?: ScreenShareDescriptorV1): string {
  if (!descriptor) return 'Нет подтверждения от отправителя'
  if (descriptor.publisher_state === 'updating' || descriptor.publisher_state === 'publishing' || descriptor.publisher_state === 'capturing') return 'Обновление конфигурации ожидается'
  if (descriptor.publisher_state !== 'sharing') return 'Предыдущая конфигурация · трансляция завершена'
  return 'Конфигурация передана отправителем'
}

export function screenDescriptorProvenanceLabel(descriptor?: ScreenShareDescriptorV1): string {
  return descriptor ? 'SDK отправителя · лимиты, не измеренный FPS' : 'Источник конфигурации неизвестен'
}

export function screenDescriptorReceivedAge(receivedAt: number | null, now = Date.now()): string {
  if (receivedAt === null || !Number.isFinite(receivedAt) || !Number.isFinite(now)) return 'Время получения неизвестно'
  const seconds = Math.max(0, Math.floor((now - receivedAt) / 1000))
  return `Получено этим клиентом ${seconds} с назад${seconds > 15 ? ' · данные могут быть устаревшими' : ''}`
}
