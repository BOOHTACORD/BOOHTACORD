import { describe, expect, it, vi } from 'vitest'

import {
  applyMicrophoneProcessing,
  BoundedVoiceReconnectPolicy,
  connectLiveKitRoom,
  microphoneConstraints,
  setMicrophone,
  wireLiveKitRoom,
  type VoiceRoom,
} from './livekit_gateway'

const credential = { url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-09-17T12:00:00Z' }

function room(microphone: () => Promise<unknown>): VoiceRoom {
  return {
    connect: vi.fn().mockResolvedValue(undefined),
    disconnect: vi.fn().mockResolvedValue(undefined),
    on: vi.fn(),
    switchActiveDevice: vi.fn().mockResolvedValue(true),
    localParticipant: {
      setMicrophoneEnabled: vi.fn(microphone),
    },
  }
}

describe('LiveKit voice gateway', () => {
  it('builds microphone constraints from the selected browser processing preferences', () => {
    expect(microphoneConstraints({ autoGainControl: false, echoCancellation: false, noiseSuppressionMode: 'off' })).toEqual({
      autoGainControl: false, channelCount: { ideal: 1 }, echoCancellation: false, noiseSuppression: false, sampleRate: { ideal: 48_000 },
    })
  })

  it('applies only browser-native processing constraints to an active local microphone track', async () => {
    const apply = vi.fn().mockResolvedValue(undefined)
    const fakeRoom = Object.assign(room(async () => undefined), { applyMicrophoneProcessing: apply })

    await applyMicrophoneProcessing(fakeRoom, { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'off' })

    expect(apply).toHaveBeenCalledWith({ autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'off' })
  })

  it('connects before requesting the microphone with browser audio processing preferences', async () => {
    const fakeRoom = room(async () => undefined)

    await expect(connectLiveKitRoom(credential, () => fakeRoom)).resolves.toMatchObject({ microphone: 'PUBLISHED' })
    expect(fakeRoom.connect).toHaveBeenCalledWith(credential.url, credential.token, { autoSubscribe: false })
    expect(fakeRoom.localParticipant.setMicrophoneEnabled).toHaveBeenCalledWith(
      true,
      expect.objectContaining({ autoGainControl: true, channelCount: { ideal: 1 }, echoCancellation: true, noiseSuppression: true }),
      { audioPreset: { maxBitrate: 128_000, priority: 'high' }, forceStereo: false, dtx: true, red: true },
    )
  })

  it('preserves the SDK connect method and enables only voice subscriptions on join', async () => {
    const fakeRoom = room(async () => undefined)
    const nativeConnect = fakeRoom.connect
    const viewer = { clear: vi.fn(), refresh: vi.fn(), subscribeMicrophones: vi.fn(), resetVoiceParticipantSounds: vi.fn(), seedVoiceParticipantSounds: vi.fn() }
    const connected = wireLiveKitRoom(fakeRoom, viewer)

    await connected.connect(credential.url, credential.token, { autoSubscribe: false })

    expect(nativeConnect).toHaveBeenCalledTimes(1)
    expect(nativeConnect).toHaveBeenCalledWith(credential.url, credential.token, { autoSubscribe: false })
    expect(viewer.resetVoiceParticipantSounds).toHaveBeenCalledOnce()
    expect(viewer.seedVoiceParticipantSounds).toHaveBeenCalledOnce()
    expect(viewer.subscribeMicrophones).toHaveBeenCalledOnce()
    expect(viewer.refresh).toHaveBeenCalledOnce()
  })

  it('keeps the joined room as a listener when microphone permission is denied', async () => {
    const denial = Object.assign(new Error('denied'), { name: 'NotAllowedError' })
    const fakeRoom = room(async () => Promise.reject(denial))

    await expect(connectLiveKitRoom(credential, () => fakeRoom)).resolves.toMatchObject({ microphone: 'LISTENER_PERMISSION_DENIED' })
    expect(fakeRoom.disconnect).not.toHaveBeenCalled()
  })

  it('closes an unresponsive media connection instead of leaving the join pending', async () => {
    const fakeRoom = room(async () => undefined)
    vi.mocked(fakeRoom.connect).mockImplementation(() => new Promise<void>(() => undefined))

    await expect(connectLiveKitRoom(credential, () => fakeRoom, undefined, 1)).rejects.toThrow('Превышено время ожидания голосового подключения.')
    expect(fakeRoom.disconnect).toHaveBeenCalledOnce()
  })

  it('closes a joined room when microphone capture does not settle', async () => {
    const fakeRoom = room(() => new Promise<never>(() => undefined))

    await expect(connectLiveKitRoom(credential, () => fakeRoom, undefined, 1)).rejects.toThrow('Превышено время ожидания голосового подключения.')
    expect(fakeRoom.connect).toHaveBeenCalledOnce()
    expect(fakeRoom.disconnect).toHaveBeenCalledOnce()
  })

  it('mutes the published microphone without leaving the room', async () => {
    const fakeRoom = room(async () => undefined)

    await expect(setMicrophone(fakeRoom, false)).resolves.toBe('MUTED')
    expect(fakeRoom.localParticipant.setMicrophoneEnabled).toHaveBeenCalledWith(false, expect.any(Object), {
      audioPreset: { maxBitrate: 128_000, priority: 'high' }, forceStereo: false, dtx: true, red: true,
    })
    expect(fakeRoom.disconnect).not.toHaveBeenCalled()
  })

})

it('uses bounded exponential reconnect delays with jitter', () => {
  const policy = new BoundedVoiceReconnectPolicy(() => 0)

  expect([0, 1, 2, 3, 4, 5].map((retryCount) => policy.nextRetryDelayInMs({ retryCount }))).toEqual([200, 400, 800, 1600, 3200, 3200])
  expect(policy.nextRetryDelayInMs({ retryCount: 6 })).toBeNull()
})
