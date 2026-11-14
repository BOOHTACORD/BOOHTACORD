import { describe, expect, it, vi } from 'vitest'

import { VoiceSession, type VoiceAdmission } from './voice_session'

function admission(): VoiceAdmission {
  return {
    acquire: vi.fn().mockResolvedValue({ id: 'lease-1', channelId: 'voice-1', transferred: false }),
    credential: vi.fn().mockResolvedValue({ url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-09-17T12:00:00Z' }),
    release: vi.fn().mockResolvedValue(undefined),
  }
}

describe('voice session', () => {
  it('carries the prejoin input selection into the room joiner, including listener joins', async () => {
    const api = admission()
    const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn() }
    const join = vi.fn(async () => ({ room: room as never, microphone: 'MUTED' as const }))
    const session = new VoiceSession(api, join)
    await session.switchAudioDevice('audioinput', 'mic-2')
    await session.join('voice-1', true, 'listener')
    expect(join).toHaveBeenCalledWith(expect.any(Object), expect.any(Object), 'listener', 'mic-2')
  })
  it('forces listener mode when the server credential forbids microphone publication', async () => {
    const api = admission()
    vi.mocked(api.credential).mockResolvedValue({
      url: 'wss://rtc.example',
      token: 'temporary',
      expiresAt: '2026-09-17T12:00:00Z',
      microphoneAllowed: false,
    })
    const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn() }
    const join = vi.fn(async () => ({ room: room as never, microphone: 'MUTED' as const }))
    const session = new VoiceSession(api, join)

    await expect(session.join('voice-afk')).resolves.toMatchObject({ listenerOnly: true, microphoneAllowed: false, microphone: 'MUTED' })
    expect(join).toHaveBeenCalledWith(expect.any(Object), expect.any(Object), 'listener', 'default')
  })
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
  it('marks a room active only after a lease, credential and room join succeed', async () => {
    const api = admission()
    const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn() }
    const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'PUBLISHED' }))

    await expect(session.join('voice-1')).resolves.toMatchObject({ leaseId: 'lease-1', channelId: 'voice-1' })
    expect(api.acquire).toHaveBeenCalledWith('voice-1', false)
    expect(api.credential).toHaveBeenCalledWith('lease-1')
  })

  it('releases a lease if later credential or media work fails', async () => {
    const api = admission()
    vi.mocked(api.credential).mockRejectedValue(new Error('expired'))
    const session = new VoiceSession(api)

    await expect(session.join('voice-1')).rejects.toThrow('expired')
    expect(api.release).toHaveBeenCalledWith('lease-1')
    expect(session.active).toBeNull()
  })
})

it('takes over an existing voice lease only after explicit confirmation', async () => {
  const api = admission()
  const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn() }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))

  await session.join('voice-next', true)

  expect(api.acquire).toHaveBeenCalledTimes(1)
  expect(api.acquire).toHaveBeenCalledWith('voice-next', true)
})

it('reports SDK reconnect state and clears a permanently disconnected lease', async () => {
  const api = admission()
  const callbacks: Record<string, () => void> = {}
  const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn((event: string, callback: () => void) => { callbacks[event] = callback }) }
  const observer = { reconnecting: vi.fn(), reconnected: vi.fn(), disconnected: vi.fn() }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))
  session.setConnectionObserver(observer)

  await session.join('voice-1')
  callbacks.reconnecting()
  callbacks.reconnected()
  callbacks.disconnected()
  await vi.waitFor(() => expect(observer.disconnected).toHaveBeenCalledOnce())

  expect(api.release).toHaveBeenCalledWith('lease-1')
  expect(session.active).toBeNull()
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
