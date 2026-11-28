import { expect, it, vi } from 'vitest'
import { VoiceSession } from '../voice_session'
import { admission } from '../room_admission/session_fixture'

it('exposes only the room-owned remote voice playback controller to UI controls', async () => {
  const api = admission()
  const remoteVoices = { cards: () => [] }
  const participantCards = { cards: () => [] }
  const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn(), participantCards, remoteVoices }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))

  await session.join('voice-1')

  expect(session.remoteVoices()).toBe(remoteVoices)
  expect(session.participantCards()).toBe(participantCards)
})

it('does not commit microphone state after the room has been revoked', async () => {
  const api = admission()
  let finish!: () => void
  const room = { disconnect: vi.fn(async () => undefined), on: vi.fn(), setMicrophone: vi.fn(() => new Promise<void>((resolve) => { finish = resolve })) }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'PUBLISHED' }))
  await session.join('voice-1')
  const muting = session.setMicrophoneMuted(true)
  await session.revoke('lease-1')
  finish()
  await expect(muting).rejects.toThrow('Голосовое подключение закрыто.')
  expect(session.active).toBeNull()
})

it('does not restore pre-failure microphone intent after deafen, even if input selection recovers', async () => {
  let observe!: (selection: { deviceId: string; outcome: 'success' | 'error' }) => void
  const stop = vi.fn()
  const room = {
    disconnect: vi.fn().mockResolvedValue(undefined),
    localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) },
    on: vi.fn(), setDeafened: vi.fn(),
    onAudioInputSelection: (listener: typeof observe) => { observe = listener; return stop },
  }
  const session = new VoiceSession(admission(), async () => ({ room: room as never, microphone: 'PUBLISHED' }))
  await session.join('voice-1')
  await session.setDeafened(true)
  observe({ deviceId: 'default', outcome: 'error' })
  observe({ deviceId: 'mic-2', outcome: 'success' })
  await session.setDeafened(false)
  expect(session.active?.microphone).toBe('MUTED')
  expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenCalledTimes(1)
  await session.setMicrophoneMuted(false)
  expect(session.active?.microphone).toBe('PUBLISHED')
  await session.leave()
  expect(stop).toHaveBeenCalledOnce()
})
