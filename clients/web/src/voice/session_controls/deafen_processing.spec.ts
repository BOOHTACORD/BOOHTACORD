import { expect, it, vi } from 'vitest'
import { VoiceSession } from '../voice_session'
import { admission } from '../room_admission/session_fixture'

it('does not try to unmute while the active credential forbids microphone publication', async () => {
    const api = admission()
    vi.mocked(api.credential).mockResolvedValue({
      url: 'wss://rtc.example',
      token: 'temporary',
      expiresAt: '2026-09-17T12:00:00Z',
      microphoneAllowed: false,
    })
    const room = {
      disconnect: vi.fn().mockResolvedValue(undefined),
      on: vi.fn(),
      localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) },
    }
    const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))

    await session.join('voice-afk')
    await expect(session.setMicrophoneMuted(false)).resolves.toBe('MUTED')

    expect(room.localParticipant.setMicrophoneEnabled).not.toHaveBeenCalled()
  })

it('deafens remote media, forces an active microphone off, then restores its former state', async () => {
  const api = admission()
  const room = {
    disconnect: vi.fn().mockResolvedValue(undefined),
    localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) },
    on: vi.fn(),
    setDeafened: vi.fn(),
  }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'PUBLISHED' }))

  await session.join('voice-1')
  await session.setDeafened(true)
  await session.setDeafened(false)

  expect(room.setDeafened).toHaveBeenNthCalledWith(1, true)
  expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenNthCalledWith(1, false, expect.any(Object), expect.any(Object))
  expect(room.setDeafened).toHaveBeenNthCalledWith(2, false)
  expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenNthCalledWith(2, true, expect.any(Object), expect.any(Object))
})

it('does not enable a microphone that was muted before deafen', async () => {
  const api = admission()
  const room = {
    disconnect: vi.fn().mockResolvedValue(undefined),
    localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) },
    on: vi.fn(),
    setDeafened: vi.fn(),
  }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))

  await session.join('voice-1')
  await session.setDeafened(true)
  await session.setDeafened(false)

  expect(room.setDeafened).toHaveBeenNthCalledWith(1, true)
  expect(room.setDeafened).toHaveBeenNthCalledWith(2, false)
  expect(room.localParticipant.setMicrophoneEnabled).not.toHaveBeenCalled()
})

it('updates an active local track and carries processing preferences through mute and deafen', async () => {
  const api = admission()
  const processing = { autoGainControl: false, echoCancellation: false, noiseSuppressionMode: 'browser' as const }
  const room = {
    applyMicrophoneProcessing: vi.fn().mockResolvedValue(undefined),
    disconnect: vi.fn().mockResolvedValue(undefined),
    localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) },
    on: vi.fn(),
    setDeafened: vi.fn(),
  }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'PUBLISHED' }))

  await session.join('voice-1')
  await session.setAudioProcessing(processing)
  await session.setMicrophoneMuted(true)
  await session.setMicrophoneMuted(false)
  await session.setDeafened(true)
  await session.setDeafened(false)

  expect(room.applyMicrophoneProcessing).toHaveBeenCalledWith(processing)
  expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenNthCalledWith(2, true, expect.objectContaining({ autoGainControl: false, echoCancellation: false, noiseSuppression: true }), expect.any(Object))
  expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenNthCalledWith(4, true, expect.objectContaining({ autoGainControl: false, echoCancellation: false, noiseSuppression: true }), expect.any(Object))
})
