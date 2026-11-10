import { describe, expect, it, vi } from 'vitest'
import { retryVoiceRoster } from './retry_action'
import { createRosterSocketState } from '../roster_socket/state'

describe('voice roster manual retry', () => {
  it('retries the shared socket and clears the action when stopped', () => {
    const reconnect = vi.fn()
    const roster = createRosterSocketState(reconnect)
    roster.start(); roster.start()
    expect(retryVoiceRoster()).toBe(true)
    expect(reconnect).toHaveBeenCalledOnce()
    roster.stop()
    expect(retryVoiceRoster()).toBe(false)
  })
})
