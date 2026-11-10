import { describe, expect, it, vi } from 'vitest'
import { connectionStatus } from './model'
import { createRosterSocketState } from '../../voice/roster_socket/state'

describe('independent chat, media and roster state', () => {
  it('retains success age while distinguishing expired and retained data', () => {
    expect(connectionStatus('CONNECTED', 'CONNECTED', false, 1000, 12000, false).roster).toBe('Состав недоступен · 11 с. назад')
    expect(connectionStatus('CONNECTED', 'CONNECTED', false, 1000, 12000, true).roster).toBe('Состав устарел · 11 с. назад')
  })
  it('does not mark connected media offline when only chat fails', () => {
    const status = connectionStatus('DISCONNECTED', 'CONNECTED', false, 1000, 6000)
    expect(status.chat).toBe('Чат обновляется')
    expect(status.voice).toBe('Голос подключён')
    expect(status.roster).toContain('Состав устарел')
  })
  it('distinguishes an unknown snapshot from an actual empty successful roster', () => {
    expect(connectionStatus('CONNECTED', 'CONNECTED', false, null, 6000).roster).toBe('Состав недоступен')
    expect(connectionStatus('CONNECTED', 'CONNECTED', false, 1000, 6000).roster).toContain('Состав устарел')
    expect(connectionStatus('CONNECTED', 'RECONNECTING', true, 1000, 6000).voice).toBe('Голос восстанавливается')
  })
  it('marks a retained roster stale and unavailable without a snapshot', () => {
    expect(connectionStatus('CONNECTED', 'CONNECTED', false, 1000, 6000).roster).toContain('Состав устарел')
    expect(connectionStatus('CONNECTED', 'CONNECTED', false, null, 6000).roster).toBe('Состав недоступен')
  })
  it('tracks last successful update and clears ownership on stop', () => {
    const roster = createRosterSocketState(vi.fn())
    roster.start(); roster.socketStart()
    roster.accept({ eventId: 'event', kind: 'voice.roster.snapshot', occurredAt: '2026-11-09T00:00:00Z', payload: { version: 1, generation: '11111111-1111-4111-8111-111111111111', revision: 1, observed_at: '2026-11-09T00:00:00Z', channels: [] } })
    const before = roster.lastUpdatedAt.value
    expect(before).not.toBeNull()
    roster.socketEnd()
    expect(roster.error.value).not.toBeNull()
    expect(roster.lastUpdatedAt.value).toBe(before)
    roster.stop()
    expect(roster.lastUpdatedAt.value).toBeNull()
  })
})
