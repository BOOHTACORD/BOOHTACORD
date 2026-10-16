import { describe, expect, it } from 'vitest'
import { voiceRoomSummary } from './voice_room_copy'

describe('voice room summary copy', () => {
  it('omits absent screen-share metadata and bounds invalid counts', () => {
    expect(voiceRoomSummary(2, 0)).toBe('2 участника')
    expect(voiceRoomSummary(21, -1)).toBe('21 участник')
    expect(voiceRoomSummary(Number.NaN, Number.POSITIVE_INFINITY)).toBe('0 участников')
  })
  it('uses truthful live participant and published-screen counts with Russian plurals', () => {
    expect(voiceRoomSummary(1, 1)).toBe('1 участник · 1 демонстрация экрана')
    expect(voiceRoomSummary(2, 3)).toBe('2 участника · 3 демонстрации экрана')
    expect(voiceRoomSummary(5, 11)).toBe('5 участников · 11 демонстраций экрана')
    expect(voiceRoomSummary(21, 22)).toBe('21 участник · 22 демонстрации экрана')
  })
})
