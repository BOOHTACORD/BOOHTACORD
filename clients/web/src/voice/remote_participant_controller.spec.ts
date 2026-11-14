import { describe, expect, it, vi } from 'vitest'

import { RemoteParticipantController } from './remote_participant_controller'

describe('remote participant controller', () => {
  it('derives microphone state from publication and refreshes cards on speaking changes', () => {
    let speaking = false
    const playbackListeners = new Set<() => void>()
    const playback = {
      isSpeaking: vi.fn(() => speaking),
      onChange: (listener: () => void) => { playbackListeners.add(listener); return () => playbackListeners.delete(listener) },
    }
    const controller = new RemoteParticipantController(() => [{ accountId: 'account-a', deafened: true, id: 'account-a', microphone: undefined, name: 'Alice' }], playback)
    const changed = vi.fn()
    controller.onChange(changed)

    controller.refresh()
    expect(controller.cards()).toEqual([{ accountId: 'account-a', deafened: true, id: 'account-a', microphoneMuted: true, name: 'Alice', speaking: false }])

    speaking = true
    playbackListeners.forEach((listener) => listener())

    expect(controller.cards()).toEqual([expect.objectContaining({ speaking: true })])
    expect(changed).toHaveBeenCalledTimes(2)
  })
})
