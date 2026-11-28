import { expect, it, vi } from 'vitest'
import { ConnectionError } from 'livekit-client'
import { VoiceSession, type VoiceAdmission } from '../voice_session'
import { VoiceRequestError } from '../admission_client'
import { connectLiveKitRoom, type VoiceRoom } from '../livekit_gateway'

const credential = { url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-11-28T10:00:00Z', microphoneAllowed: true }
function setup() {
  const first = { connect: vi.fn().mockRejectedValue(ConnectionError.websocket('early signal error')), disconnect: vi.fn().mockResolvedValue(undefined) }
  const second = { connect: vi.fn().mockResolvedValue(undefined), disconnect: vi.fn(), on: vi.fn(),
    localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) }, switchActiveDevice: vi.fn().mockResolvedValue(true) }
  const factory = vi.fn().mockReturnValueOnce(first).mockReturnValueOnce(second)
  const api: VoiceAdmission = {
    acquire: vi.fn().mockResolvedValue({ id: 'exact-lease', channelId: 'voice', transferred: false }),
    credential: vi.fn().mockResolvedValue(credential), release: vi.fn().mockResolvedValue(undefined),
  }
  const session = new VoiceSession(api, (value, processing, mode, input, options) =>
    connectLiveKitRoom(value, factory as () => VoiceRoom, processing, undefined, mode, input, options))
  return { api, session, factory, first, second }
}

it.each([401, 403, 404])('stops before another media connection when the exact lease is rejected with %s', async status => {
  const { api, session, factory } = setup(), denied = new VoiceRequestError(status)
  vi.mocked(api.credential).mockResolvedValueOnce(credential).mockRejectedValueOnce(denied)
  await expect(session.join('voice', false, 'listener')).rejects.toBe(denied)
  expect(api.acquire).toHaveBeenCalledOnce()
  expect(api.credential).toHaveBeenNthCalledWith(2, 'exact-lease')
  expect(factory).toHaveBeenCalledOnce()
  expect(api.release).toHaveBeenCalledExactlyOnceWith('exact-lease')
  expect(session.active).toBeNull()
})

it('honors a new microphone restriction without acquiring or transferring another lease', async () => {
  const { api, session, factory, second } = setup()
  vi.mocked(api.credential).mockResolvedValueOnce(credential).mockResolvedValueOnce({ ...credential, token: 'renewed', microphoneAllowed: false })
  await expect(session.join('voice')).resolves.toMatchObject({ listenerOnly: true, microphoneAllowed: false, microphone: 'MUTED' })
  expect(factory).toHaveBeenCalledTimes(2)
  expect(second.connect).toHaveBeenCalledWith(credential.url, 'renewed', { autoSubscribe: false })
  expect(second.localParticipant.setMicrophoneEnabled).not.toHaveBeenCalled()
  expect(api.acquire).toHaveBeenCalledExactlyOnceWith('voice', false)
  expect(api.release).not.toHaveBeenCalled()
})
