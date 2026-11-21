import { expect, it, vi } from 'vitest'
import { VoiceSession, type VoiceAdmission } from '../voice_session'
import { cleanupFailedVoiceJoin } from './cleanup'

it('cleans up a joined room when post-connect setup fails and permits a fresh join', async () => {
  const admission: VoiceAdmission = {
    acquire: vi.fn().mockResolvedValue({ id: 'lease-1', channelId: 'voice-1', transferred: false }),
    credential: vi.fn().mockResolvedValue({ url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-09-17T12:00:00Z' }),
    release: vi.fn().mockResolvedValue(undefined),
  }
  const failedRoom = {
    bindScreenPreviewLease: vi.fn().mockRejectedValue(new Error('preview setup failed')),
    stopScreenPreview: vi.fn().mockResolvedValue(undefined),
    disconnect: vi.fn().mockResolvedValue(undefined),
    on: vi.fn(),
  }
  const nextRoom = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn() }
  const join = vi.fn().mockResolvedValueOnce({ room: failedRoom, microphone: 'MUTED' })
    .mockResolvedValueOnce({ room: nextRoom, microphone: 'MUTED' })
  const session = new VoiceSession(admission, join)

  await expect(session.join('voice-1')).rejects.toThrow('preview setup failed')
  expect(session.active).toBeNull()
  expect(failedRoom.stopScreenPreview).toHaveBeenCalledOnce()
  expect(failedRoom.disconnect).toHaveBeenCalledOnce()
  expect(admission.release).toHaveBeenCalledWith('lease-1')
  expect(failedRoom.disconnect.mock.invocationCallOrder[0]).toBeLessThan(vi.mocked(admission.release).mock.invocationCallOrder[0]!)
  await expect(session.join('voice-1')).resolves.toMatchObject({ room: nextRoom })
})

it('retains the setup error and releases the lease when room cleanup also fails', async () => {
  const admission: VoiceAdmission = {
    acquire: vi.fn().mockResolvedValue({ id: 'lease-2', channelId: 'voice-1', transferred: false }),
    credential: vi.fn().mockResolvedValue({ url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-09-17T12:00:00Z' }),
    release: vi.fn().mockResolvedValue(undefined),
  }
  const room = {
    bindScreenPreviewLease: vi.fn().mockRejectedValue(new Error('setup failed')),
    stopScreenPreview: vi.fn().mockRejectedValue(new Error('preview cleanup failed')),
    disconnect: vi.fn().mockRejectedValue(new Error('disconnect failed')),
    on: vi.fn(),
  }
  const session = new VoiceSession(admission, async () => ({ room: room as never, microphone: 'MUTED' }))

  await expect(session.join('voice-1')).rejects.toThrow('setup failed')
  expect(session.active).toBeNull()
  expect(room.disconnect).toHaveBeenCalledOnce()
  expect(admission.release).toHaveBeenCalledWith('lease-2')
})

it('does not clear a newer active room while cleaning up an older failed join', async () => {
  const oldRoom = { disconnect: vi.fn().mockResolvedValue(undefined) }
  const newerRoom = { disconnect: vi.fn().mockResolvedValue(undefined) }
  const release = vi.fn().mockResolvedValue(undefined)
  const state = {
    current: () => ({ room: newerRoom }) as never,
    setCurrent: vi.fn(), stopInputSelection: vi.fn(), setStopInputSelection: vi.fn(),
    screen: { cancel: vi.fn() }, deafen: { reset: vi.fn() },
  }

  await cleanupFailedVoiceJoin(state, oldRoom as never, release)
  expect(state.setCurrent).not.toHaveBeenCalled()
  expect(state.screen.cancel).not.toHaveBeenCalled()
  expect(newerRoom.disconnect).not.toHaveBeenCalled()
  expect(oldRoom.disconnect).toHaveBeenCalledOnce()
  expect(release).toHaveBeenCalledOnce()
})
