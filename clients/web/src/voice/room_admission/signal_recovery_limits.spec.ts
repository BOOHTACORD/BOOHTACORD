import { afterEach, expect, it, vi } from 'vitest'
import { ConnectionError } from 'livekit-client'
import { connectLiveKitRoom, type VoiceRoom } from '../livekit_gateway'

const credential = { url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-11-28T10:00:00Z' }
const failure = () => ConnectionError.websocket('could not establish signal connection: Encountered websocket error during connection establishment')
function room(connect = vi.fn().mockResolvedValue(undefined)): VoiceRoom {
  return { connect, disconnect: vi.fn().mockResolvedValue(undefined), switchActiveDevice: vi.fn().mockResolvedValue(true),
    localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) } } as unknown as VoiceRoom
}
afterEach(() => { vi.restoreAllMocks(); vi.useRealTimers() })

it('uses one total connection deadline across both signaling attempts', async () => {
  vi.useFakeTimers()
  const first = room(vi.fn(() => new Promise((_, reject) => setTimeout(() => reject(failure()), 4000))))
  const second = room(vi.fn(() => new Promise(() => {})))
  const factory = vi.fn().mockReturnValueOnce(first).mockReturnValueOnce(second), failed = vi.fn()
  void connectLiveKitRoom(credential, factory, undefined, 10000, 'listener').catch(failed)
  await vi.advanceTimersByTimeAsync(9999)
  expect(failed).not.toHaveBeenCalled()
  expect(factory).toHaveBeenCalledTimes(2)
  await vi.advanceTimersByTimeAsync(1)
  expect(failed).toHaveBeenCalledWith(expect.objectContaining({ message: 'Превышено время ожидания голосового подключения.' }))
  expect(second.disconnect).toHaveBeenCalledOnce()
})

it('does not open another room when the owner cancels during failed-room cleanup', async () => {
  let current = true
  const first = room(vi.fn().mockRejectedValue(failure())), factory = vi.fn(() => first)
  vi.mocked(first.disconnect).mockImplementation(async () => { current = false })
  await expect(connectLiveKitRoom(credential, factory, undefined, 20000, 'listener', undefined, { current: () => current })).rejects.toThrow('отменено')
  expect(factory).toHaveBeenCalledOnce()
})

it('does not connect or capture if admission was cancelled while constructing the room', async () => {
  let current = true
  const created = room(), factory = vi.fn(async () => { current = false; return created })
  await expect(connectLiveKitRoom(credential, factory, undefined, 20000, 'with-microphone', undefined, { current: () => current })).rejects.toThrow('отменено')
  expect(created.connect).not.toHaveBeenCalled()
  expect(created.localParticipant.setMicrophoneEnabled).not.toHaveBeenCalled()
  expect(created.disconnect).toHaveBeenCalledOnce()
})

it('does not publish a microphone after cancellation during connect', async () => {
  let current = true
  const created = room(vi.fn(async () => { current = false }))
  await expect(connectLiveKitRoom(credential, () => created, undefined, 20000, 'with-microphone', undefined, { current: () => current })).rejects.toThrow('отменено')
  expect(created.localParticipant.setMicrophoneEnabled).not.toHaveBeenCalled()
  expect(created.disconnect).toHaveBeenCalledOnce()
})

it('does not retry device selection even when its error has a WebSocket reason', async () => {
  const created = room(), rejected = failure(), factory = vi.fn(() => created)
  vi.mocked(created.switchActiveDevice).mockRejectedValue(rejected)
  await expect(connectLiveKitRoom(credential, factory, undefined, 20000, 'listener', 'chosen')).rejects.toBe(rejected)
  expect(factory).toHaveBeenCalledOnce()
})

it('does not construct another room when credential revalidation consumes the remaining budget', async () => {
  vi.useFakeTimers()
  const first = room(vi.fn().mockRejectedValue(failure())), second = room()
  const factory = vi.fn().mockReturnValueOnce(first).mockReturnValueOnce(second), failed = vi.fn()
  const refreshCredential = () => new Promise<typeof credential>(resolve => setTimeout(() => resolve(credential), 18000))
  void connectLiveKitRoom(credential, factory, undefined, 20000, 'listener', undefined, { refreshCredential }).catch(failed)
  await vi.advanceTimersByTimeAsync(20000)
  expect(failed).toHaveBeenCalledWith(expect.objectContaining({ message: 'Превышено время ожидания голосового подключения.' }))
  expect(factory).toHaveBeenCalledOnce()
  expect(second.connect).not.toHaveBeenCalled()
})
