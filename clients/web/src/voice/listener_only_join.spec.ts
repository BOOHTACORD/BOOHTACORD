import { describe, expect, it, vi } from 'vitest'

import { connectLiveKitRoom, type VoiceRoom } from './livekit_gateway'
import { VoiceSession, type RoomJoiner, type VoiceAdmission } from './voice_session'

const credential = { url: 'wss://rtc.example', token: 'test-token', expiresAt: '2026-09-24T12:00:00Z' }

function makeRoom(): VoiceRoom {
  return {
    connect: vi.fn().mockResolvedValue(undefined),
    disconnect: vi.fn().mockResolvedValue(undefined),
    on: vi.fn().mockReturnThis(),
    switchActiveDevice: vi.fn().mockResolvedValue(true),
    localParticipant: {
      setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined),
    },
  }
}

function makeAdmission(): VoiceAdmission {
  return {
    acquire: vi.fn().mockResolvedValue({ id: 'lease-1', channelId: 'voice-1', transferred: false }),
    credential: vi.fn().mockResolvedValue(credential),
    release: vi.fn().mockResolvedValue(undefined),
  }
}

describe('listener-only voice join', () => {
  it('connects without requesting or publishing microphone audio', async () => {
    const room = makeRoom()

    await expect(connectLiveKitRoom(credential, () => room, undefined, undefined, 'listener')).resolves.toMatchObject({ microphone: 'MUTED' })

    expect(room.connect).toHaveBeenCalledWith(credential.url, credential.token, { autoSubscribe: false })
    expect(room.localParticipant.setMicrophoneEnabled).not.toHaveBeenCalled()
  })

  it('passes listener mode through the leased voice session', async () => {
    const admission = makeAdmission()
    const room = makeRoom()
    const joinRoom: RoomJoiner = vi.fn().mockResolvedValue({ room, microphone: 'MUTED' })
    const session = new VoiceSession(admission, joinRoom)

    await expect(session.join('voice-1', false, 'listener')).resolves.toMatchObject({ microphone: 'MUTED', channelId: 'voice-1' })

    expect(joinRoom).toHaveBeenCalledWith(credential, expect.any(Object), 'listener', 'default', expect.objectContaining({ refreshCredential: expect.any(Function) }))
    expect(admission.release).not.toHaveBeenCalled()
  })
})
