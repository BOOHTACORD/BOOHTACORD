import { afterEach, expect, it, vi } from 'vitest'
import { ConnectionError } from 'livekit-client'
import { connectLiveKitRoom, type VoiceRoom } from '../livekit_gateway'

const credential = { url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-11-28T10:00:00Z' }
const signalFailure = () => ConnectionError.websocket('could not establish signal connection: Encountered websocket error during connection establishment')
function room(connect = vi.fn().mockResolvedValue(undefined)): VoiceRoom {
  return { connect, disconnect: vi.fn().mockResolvedValue(undefined), switchActiveDevice: vi.fn(),
    localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) } } as unknown as VoiceRoom
}
afterEach(() => vi.useRealTimers())

it('rejoins after an early WebSocket failure with a fresh room and the same credential', async () => {
  const failed = room(vi.fn().mockRejectedValue(signalFailure())), successor = room()
  const factory = vi.fn().mockReturnValueOnce(failed).mockImplementationOnce(() => {
    expect(failed.disconnect).toHaveBeenCalledOnce()
    return successor
  })
  await expect(connectLiveKitRoom(credential, factory, undefined, 20000, 'listener')).resolves.toMatchObject({ room: successor, microphone: 'MUTED' })
  expect(factory).toHaveBeenCalledTimes(2)
  expect(successor.connect).toHaveBeenCalledWith(credential.url, credential.token, { autoSubscribe: false })
  expect(failed.localParticipant.setMicrophoneEnabled).not.toHaveBeenCalled()
  expect(successor.localParticipant.setMicrophoneEnabled).not.toHaveBeenCalled()
})

it('caps transport recovery at one retry and preserves the second failure', async () => {
  const first = room(vi.fn().mockRejectedValue(signalFailure())), failure = signalFailure()
  const second = room(vi.fn().mockRejectedValue(failure)), factory = vi.fn().mockReturnValueOnce(first).mockReturnValueOnce(second)
  await expect(connectLiveKitRoom(credential, factory)).rejects.toBe(failure)
  expect(factory).toHaveBeenCalledTimes(2)
  expect(first.disconnect).toHaveBeenCalledOnce(); expect(second.disconnect).toHaveBeenCalledOnce()
})

it.each([ConnectionError.notAllowed('denied', 401), ConnectionError.notAllowed('denied', 403), ConnectionError.websocket('denied', 403),
  ConnectionError.cancelled('cancelled'), ConnectionError.timeout('timeout'), ConnectionError.internal('peer connection failed'),
  new Error('unknown failure')])('does not retry non-WebSocket failures: %s', async failure => {
  const factory = vi.fn(() => room(vi.fn().mockRejectedValue(failure)))
  await expect(connectLiveKitRoom(credential, factory)).rejects.toBe(failure)
  expect(factory).toHaveBeenCalledOnce()
})

it('does not retry microphone publication after the room connects', async () => {
  const joined = room(), failure = signalFailure(), factory = vi.fn(() => joined)
  vi.mocked(joined.localParticipant.setMicrophoneEnabled).mockRejectedValue(failure)
  await expect(connectLiveKitRoom(credential, factory)).rejects.toBe(failure)
  expect(factory).toHaveBeenCalledOnce()
  expect(joined.disconnect).toHaveBeenCalledOnce()
})
