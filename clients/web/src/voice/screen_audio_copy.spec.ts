import { describe, expect, it } from 'vitest'
import { participantAudioMessage, screenAudioMessage } from './screen_audio_copy'

describe('screen audio copy', () => {
  it('separates track presence from audible game sound', () => {
    expect(screenAudioMessage({ isLocal: false, hasAudio: true, adjustable: true })).toBe('')
    expect(screenAudioMessage({ isLocal: false, hasAudio: true, adjustable: false })).toBe('Аудиодорожка есть; личная настройка громкости недоступна.')
    expect(screenAudioMessage({ isLocal: false, hasAudio: false, adjustable: false })).toBe('У демонстрации нет аудиодорожки.')
  })

  it('keeps screen audio messaging independent from participant deafen', () => {
    expect(screenAudioMessage({ isLocal: true, hasAudio: true, adjustable: false })).toBe('Предпросмотр собственного экрана без звука.')
    expect(screenAudioMessage({ isLocal: false, hasAudio: true, adjustable: true })).toBe('')
    expect(participantAudioMessage(true)).toBe('Удалённый звук выключен.')
    expect(participantAudioMessage(false)).toBe('Звук участников управляется отдельно от демонстрации.')
  })
})
