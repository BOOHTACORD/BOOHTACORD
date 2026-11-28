import { expect, it, vi } from 'vitest'
import { VoiceSession } from './voice_session'
import { admission } from './room_admission/session_fixture'

it('carries the prejoin input selection into the room joiner, including listener joins', async () => {
    const api = admission()
    const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn() }
    const join = vi.fn(async () => ({ room: room as never, microphone: 'MUTED' as const }))
    const session = new VoiceSession(api, join)
    await session.switchAudioDevice('audioinput', 'mic-2')
    await session.join('voice-1', true, 'listener')
    expect(join).toHaveBeenCalledWith(expect.any(Object), expect.any(Object), 'listener', 'mic-2', expect.objectContaining({ refreshCredential: expect.any(Function) }))
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
    expect(join).toHaveBeenCalledWith(expect.any(Object), expect.any(Object), 'listener', 'default', expect.objectContaining({ refreshCredential: expect.any(Function) }))
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
