import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(relativePath: string): string {
  try { return readFileSync(new URL(relativePath, import.meta.url), 'utf8') }
  catch { return '' }
}

describe('disconnected voice-room presentation', () => {
  it('uses a centered branded join state and explains when live participants appear', () => {
    const pane = source('../conversation/ConversationPane.vue')
    const prejoin = source('./VoicePrejoin.vue')
    const styles = source('../design/voice.css')

    expect(pane).toContain('<VoicePrejoin')
    for (const text of ['voice-prejoin-title', 'Войти', 'Без микрофона', 'voiceError', "voiceState === 'JOINING'"]) expect(prejoin).toContain(text)
    expect(prejoin).not.toContain('Перенести подключение')
    expect(styles).toContain('.voice-prejoin {')
    expect(styles).toContain('.voice-prejoin-card {')
  })
})
