import { describe, expect, it, vi } from 'vitest'

import { VoiceVolumePreferences } from './voice_volume_preferences'
import { createVoiceVolumeControls } from './voice_volume_controls'

function storage() {
  const values = new Map<string, string>()
  return { getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => values.set(key, value) }
}

describe('voice volume account lookup', () => {
  it('does not let a stale account lookup redirect a later volume change', async () => {
    const local = storage()
    const preferences = new VoiceVolumePreferences(local)
    let resolveFirst!: (account: { accountId: string }) => void
    const firstAccount = new Promise<{ accountId: string }>((resolve) => { resolveFirst = resolve })
    let lookupCount = 0
    const loadAccount = () => ++lookupCount === 1 ? firstAccount : Promise.resolve({ accountId: 'current-owner' })
    const remote = { setVolume: vi.fn() }
    const participantCards = { cards: () => [{ accountId: 'remote-a', id: 'track-a', microphoneMuted: false, deafened: false, name: 'Alice', speaking: false }], onChange: () => () => undefined }
    const controls = createVoiceVolumeControls({ participantCards: () => participantCards, remoteVoices: () => remote as never, screenViewer: () => null }, loadAccount, preferences)

    const staleStart = controls.start()
    await controls.start()
    resolveFirst({ accountId: 'previous-owner' })
    await staleStart
    controls.setParticipantVolume('track-a', 175)

    controls.flush()
    const current = new VoiceVolumePreferences(local)
    current.bind('current-owner')
    const previous = new VoiceVolumePreferences(local)
    previous.bind('previous-owner')
    expect(current.participant('remote-a')).toBe(175)
    expect(previous.participant('remote-a')).toBe(100)
    expect(remote.setVolume).toHaveBeenLastCalledWith('track-a', 175)
  })

  it('does not clear the current account when an older lookup fails', async () => {
    const local = storage()
    let rejectFirst!: (reason: Error) => void
    const firstAccount = new Promise<{ accountId: string }>((_resolve, reject) => { rejectFirst = reject })
    let lookupCount = 0
    const remote = { setVolume: vi.fn() }
    const participantCards = { cards: () => [{ accountId: 'remote-a', id: 'track-a', microphoneMuted: false, deafened: false, name: 'Alice', speaking: false }], onChange: () => () => undefined }
    const controls = createVoiceVolumeControls({ participantCards: () => participantCards, remoteVoices: () => remote as never, screenViewer: () => null }, () => ++lookupCount === 1 ? firstAccount : Promise.resolve({ accountId: 'current-owner' }), new VoiceVolumePreferences(local))

    const staleStart = controls.start()
    await controls.start()
    rejectFirst(new Error('old session expired'))
    await staleStart
    controls.setParticipantVolume('track-a', 200)

    controls.flush()
    const current = new VoiceVolumePreferences(local)
    current.bind('current-owner')
    expect(current.participant('remote-a')).toBe(200)
    expect(controls.error.value).toBeNull()
  })
})
