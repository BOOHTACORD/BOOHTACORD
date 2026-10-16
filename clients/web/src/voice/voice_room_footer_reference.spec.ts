import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'
import VoiceRoomFooter from './VoiceRoomFooter.vue'

describe('compact voice-room status', () => {
  for (const [state, message] of [['JOINING', 'Подключаемся'], ['CONNECTED', 'В голосе'], ['LISTENER', 'Режим слушателя'], ['RECONNECTING', 'Восстанавливаем связь'], ['LEAVING', 'Завершаем голосовое подключение']] as const) it(`announces ${state} without duplicating the primary controls`, async () => {
    const html = await renderToString(createSSRApp(VoiceRoomFooter, { channelName: 'Игровая', state, activationMode: 'VAD', participantCount: 2, screenCount: 0 }))
    expect(html).toContain(message)
    expect(html).toContain('role="status"')
    expect(html).not.toContain('<button')
    expect(html).not.toContain('128 кбит/с')
    if (state === 'LEAVING') expect(html).not.toContain('2 участника')
    else expect(html).toContain('2 участника')
  })
})
