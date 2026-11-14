import { expect, it, vi } from 'vitest'
import { VoiceVolumePreferences } from './preferences'
import { createVoiceVolumeControls } from './controls'
it('restores by account across new SID/name, rejoin, logout and another owner', async () => {
  const saved = new Map<string, string>()
  const prefs = new VoiceVolumePreferences({ getItem: key => saved.get(key) ?? null, setItem: (key, value) => { saved.set(key, value) } })
  let owner = 'owner', id = 'old-sid', name = 'Alice', changed = () => {}
  const remote = { setVolume: vi.fn() }
  const cards = { cards: () => [{ accountId: 'peer', id, name, microphoneMuted: false, deafened: false, speaking: false }], onChange: (listener: () => void) => { changed = listener; return () => { changed = () => {} } } }
  const controls = createVoiceVolumeControls({ participantCards: () => cards, remoteVoices: () => remote as never, screenViewer: () => null }, async () => ({ accountId: owner }), prefs)
  await controls.start(); controls.setParticipantVolume(id, 175)
  id = 'new-sid'; name = 'Renamed'; changed()
  expect(remote.setVolume).toHaveBeenLastCalledWith('new-sid', 175)
  controls.stop(); await controls.start()
  expect(controls.participants.value[0]?.volume).toBe(175)
  controls.stop(); owner = 'other'; await controls.start()
  expect(controls.participants.value[0]?.volume).toBe(100)
  controls.stop(); owner = 'owner'; await controls.start()
  expect(controls.participants.value[0]?.volume).toBe(175)
  await controls.reset()
  expect(remote.setVolume).toHaveBeenLastCalledWith('new-sid', 100)
  controls.dispose()
})
it('does not let a delayed reset cross logout', async () => {
  let resolve!: (value: { accountId: string }) => void
  const prefs = new VoiceVolumePreferences(null)
  const controls = createVoiceVolumeControls({ participantCards: () => null, remoteVoices: () => null, screenViewer: () => null }, () => new Promise(done => { resolve = done }), prefs)
  const resetting = controls.reset(); controls.stop(); resolve({ accountId: 'old-owner' }); await resetting
  prefs.bind('new-owner'); expect(prefs.participant('peer')).toBe(100)
  controls.dispose()
})
