import { describe, expect, it, vi } from 'vitest'

import { VoiceVolumePreferences } from './voice_volume_preferences'
import { createVoiceVolumeControls } from './voice_volume_controls'

function storage() {
  const values = new Map<string, string>()
  return { getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => values.set(key, value) }
}

describe('voice volume controls', () => {
  it('applies and persists separate remote microphone and selected-stream levels', async () => {
    const remote = { setVolume: vi.fn() }
    const participantCards = { cards: () => [{ accountId: 'remote-a', id: 'track-a', microphoneMuted: true, deafened: false, name: 'Alice', speaking: false }], onChange: vi.fn(() => () => undefined) }
    const screen = { onChange: vi.fn(() => () => undefined), selectedAccountId: 'remote-a', setAudioVolume: vi.fn() }
    const preferences = new VoiceVolumePreferences(storage())
    const controls = createVoiceVolumeControls({ participantCards: () => participantCards, remoteVoices: () => remote as never, screenViewer: () => screen as never }, async () => ({ accountId: 'owner-a' }), preferences)

    await controls.start()
    controls.setParticipantVolume('track-a', 175)
    controls.setScreenVolume(35)

    expect(remote.setVolume).toHaveBeenCalledWith('track-a', 100)
    expect(remote.setVolume).toHaveBeenLastCalledWith('track-a', 175)
    expect(screen.setAudioVolume).toHaveBeenCalledWith(100)
    expect(screen.setAudioVolume).toHaveBeenLastCalledWith(35)
    expect(controls.participants.value).toEqual([{ accountId: 'remote-a', id: 'track-a', microphoneMuted: true, deafened: false, name: 'Alice', speaking: false, volume: 175 }])
    expect(preferences.participant('remote-a')).toBe(175)
    expect(preferences.screen('remote-a')).toBe(35)
  })

  it('keeps audio at defaults and reports a non-blocking error when the account lookup fails', async () => {
    const remote = { setVolume: vi.fn() }
    const participantCards = { cards: () => [{ accountId: 'remote-a', id: 'track-a', microphoneMuted: false, deafened: false, name: 'Alice', speaking: false }], onChange: () => () => undefined }
    const controls = createVoiceVolumeControls({ participantCards: () => participantCards, remoteVoices: () => remote as never, screenViewer: () => null }, async () => Promise.reject(new Error('session unavailable')), new VoiceVolumePreferences(storage()))

    await controls.start()

    expect(remote.setVolume).toHaveBeenCalledWith('track-a', 100)
    expect(controls.error.value).toContain('100%')
  })

  it.each([
    { name: 'browser storage is unavailable', loadAccount: async () => ({ accountId: 'owner-a' }) },
    { name: 'account lookup fails', loadAccount: async () => Promise.reject(new Error('session unavailable')) },
  ])('still changes the remote gain when $name', async ({ loadAccount }) => {
    const remote = { setVolume: vi.fn() }
    const participantCards = { cards: () => [{ accountId: 'remote-a', id: 'track-a', microphoneMuted: false, deafened: false, name: 'Alice', speaking: false }], onChange: () => () => undefined }
    const controls = createVoiceVolumeControls({ participantCards: () => participantCards, remoteVoices: () => remote as never, screenViewer: () => null }, loadAccount, new VoiceVolumePreferences(null))

    await controls.start()
    controls.setParticipantVolume('track-a', 175)

    expect(remote.setVolume).toHaveBeenLastCalledWith('track-a', 175)
    expect(controls.participants.value[0]?.volume).toBe(175)
  })

  it('does not reuse a previous account preference when the next account lookup fails', async () => {
    const preferences = new VoiceVolumePreferences(null)
    preferences.bind('previous-owner')
    preferences.setParticipant('remote-a', 175)
    const remote = { setVolume: vi.fn() }
    const participantCards = { cards: () => [{ accountId: 'remote-a', id: 'track-a', microphoneMuted: false, deafened: false, name: 'Alice', speaking: false }], onChange: () => () => undefined }
    const controls = createVoiceVolumeControls({ participantCards: () => participantCards, remoteVoices: () => remote as never, screenViewer: () => null }, async () => Promise.reject(new Error('session unavailable')), preferences)

    await controls.start()
    expect(controls.participants.value[0]?.volume).toBe(100)
    controls.setParticipantVolume('track-a', 80)
    expect(remote.setVolume).toHaveBeenLastCalledWith('track-a', 80)
    expect(preferences.participant('remote-a')).toBe(80)
  })

  it('tracks the authenticated participant speaking state and clears it when stopped', async () => {
    let speaking = false
    let changed: () => void = () => undefined
    const remote = {
      isSpeaking: () => speaking,
      onChange: (listener: () => void) => { changed = listener; return () => { changed = () => undefined } },
      setVolume: vi.fn(),
    }
    const controls = createVoiceVolumeControls({ participantCards: () => null, remoteVoices: () => remote, screenViewer: () => null }, async () => ({ accountId: 'owner-account' }), new VoiceVolumePreferences(storage()))

    await controls.start()
    expect(controls.selfSpeaking.value).toBe(false)
    speaking = true
    changed()
    expect(controls.selfSpeaking.value).toBe(true)
    controls.stop()
    expect(controls.selfSpeaking.value).toBe(false)
  })
})
