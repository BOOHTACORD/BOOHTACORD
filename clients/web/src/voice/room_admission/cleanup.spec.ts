import { afterEach, expect, it, vi } from 'vitest'
import { connectLiveKitRoom, type VoiceRoom } from '../livekit_gateway'
import { VoiceSession, type VoiceAdmission } from '../voice_session'

const credential = { url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-09-17T12:00:00Z' }
afterEach(() => vi.useRealTimers())

function fakeRoom(disconnect: () => Promise<void>, failure: Error): VoiceRoom {
  return {
    connect: vi.fn().mockRejectedValue(failure), disconnect: vi.fn(disconnect),
    on: vi.fn(), switchActiveDevice: vi.fn(),
    localParticipant: { setMicrophoneEnabled: vi.fn() },
  } as unknown as VoiceRoom
}

it('preserves the original connection error when cleanup rejects', async () => {
  const failure = new Error('original connection failure')
  const room = fakeRoom(async () => { throw new Error('cleanup failure') }, failure)
  await expect(connectLiveKitRoom(credential, () => room)).rejects.toBe(failure)
  expect(room.disconnect).toHaveBeenCalledOnce()
})

it('preserves a microphone failure when disconnect also rejects', async () => {
  const failure = new Error('original microphone failure')
  const room = fakeRoom(async () => { throw new Error('cleanup failure') }, failure)
  vi.mocked(room.connect).mockResolvedValue(undefined)
  vi.mocked(room.localParticipant.setMicrophoneEnabled).mockRejectedValue(failure)
  await expect(connectLiveKitRoom(credential, () => room)).rejects.toBe(failure)
  expect(room.disconnect).toHaveBeenCalledOnce()
})

it('releases the lease when disconnect never settles after a failed connection', async () => {
  vi.useFakeTimers()
  const failure = new Error('original connection failure')
  const room = fakeRoom(() => new Promise<void>(() => {}), failure)
  const admission: VoiceAdmission = {
    acquire: vi.fn().mockResolvedValue({ id: 'owned-lease', channelId: 'voice', transferred: false }),
    credential: vi.fn().mockResolvedValue(credential),
    release: vi.fn().mockResolvedValue(undefined),
  }
  const session = new VoiceSession(admission, (value) => connectLiveKitRoom(value, () => room))
  const failed = vi.fn()
  void session.join('voice').catch(failed)
  await vi.advanceTimersByTimeAsync(2500)
  expect(failed).toHaveBeenCalledWith(failure)
  expect(admission.release).toHaveBeenCalledWith('owned-lease')
  expect(session.active).toBeNull()
})
