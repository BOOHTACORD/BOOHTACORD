import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { VoiceRequestError } from '../admission_client'
import VoicePrejoin from '../VoicePrejoin.vue'
import type { ActiveVoiceSession } from '../voice_session'
import { joinedSession, setup, type SessionJoin } from './join_fixture'

describe('automatic voice handoff on an explicit channel join', () => {
  beforeEach(() => vi.clearAllMocks())

  it('retries an active server lease once with transfer and preserves listener-only intent', async () => {
    const sessionJoin = vi.fn<SessionJoin>()
      .mockRejectedValueOnce(new VoiceRequestError(409, 'ACTIVE_VOICE_LEASE', 'voice-origin'))
      .mockResolvedValueOnce(joinedSession)
    const { active, join, state, claim } = setup(sessionJoin, vi.fn(async () => true))

    await join('voice-target', false, 'listener')

    expect(sessionJoin).toHaveBeenNthCalledWith(1, 'voice-target', false, 'listener', expect.any(Function))
    expect(sessionJoin).toHaveBeenNthCalledWith(2, 'voice-target', true, 'listener', expect.any(Function))
    expect(sessionJoin).toHaveBeenCalledTimes(2)
    expect(claim).toHaveBeenCalledOnce()
    expect(active.value).toBe(joinedSession)
    expect(state.value).toBe('LISTENER')
  })

  it('immediately yields the browser controller and retries when another tab owns media', async () => {
    let complete!: (value: ActiveVoiceSession) => void
    const sessionJoin = vi.fn<SessionJoin>(async () => new Promise((resolve) => { complete = resolve }))
    const claim = vi.fn(async (_channel: string, transfer: boolean) => transfer)
    const { active, join, state, transferRequired } = setup(sessionJoin, claim)

    const joining = join('voice-target', false, 'listener')
    await vi.waitFor(() => expect(sessionJoin).toHaveBeenCalledOnce())
    expect(claim).toHaveBeenNthCalledWith(1, 'voice-target', false)
    expect(claim).toHaveBeenNthCalledWith(2, 'voice-target', true)
    expect(sessionJoin).toHaveBeenCalledWith('voice-target', true, 'listener', expect.any(Function))
    expect(transferRequired.value).toBe(true)
    complete(joinedSession)
    await joining
    expect(transferRequired.value).toBe(false)
    expect(active.value).toBe(joinedSession)
    expect(state.value).toBe('LISTENER')
  })

  it('does not loop if the server still rejects the transferred lease', async () => {
    const sessionJoin = vi.fn<SessionJoin>()
      .mockRejectedValueOnce(new VoiceRequestError(409, 'ACTIVE_VOICE_LEASE', 'voice-origin'))
      .mockRejectedValueOnce(new VoiceRequestError(409, 'ACTIVE_VOICE_LEASE', 'voice-origin'))
    const { active, error, join, state } = setup(sessionJoin, vi.fn(async () => true))

    await join('voice-target')

    expect(sessionJoin).toHaveBeenCalledTimes(2)
    expect(active.value).toBeNull()
    expect(state.value).toBe('ERROR')
    expect(error.value).toContain('ACTIVE_VOICE_LEASE')
  })
})


it('shows transfer progress without asking for confirmation', async () => {
  const html = await renderToString(createSSRApp({
    render: () => h(VoicePrejoin, {
      channelId: 'voice-target',
      voiceError: null,
      voiceState: 'JOINING',
      voiceTransferRequired: true,
    }),
  }))

  expect(html).toContain('Переносим голосовое подключение…')
  expect(html).not.toContain('<dialog')
  expect(html).not.toContain('Перенести подключение сюда')
})


it('never transfers another active server lease during automatic recovery', async () => {
  const sessionJoin = vi.fn<SessionJoin>().mockRejectedValueOnce(
    new VoiceRequestError(409, 'ACTIVE_VOICE_LEASE', 'voice-other-device'),
  )
  const { active, join, state, error } = setup(sessionJoin, vi.fn(async () => true))

  await join('voice-target', false, 'listener', false, true)

  expect(sessionJoin).toHaveBeenCalledTimes(1)
  expect(sessionJoin).toHaveBeenCalledWith('voice-target', false, 'listener', expect.any(Function))
  expect(active.value).toBeNull()
  expect(state.value).toBe('ERROR')
  expect(error.value).toContain('ACTIVE_VOICE_LEASE')
})

it('does not steal the media controller from another tab during recovery', async () => {
  const sessionJoin = vi.fn<SessionJoin>()
  const { join, claim, state } = setup(sessionJoin, vi.fn(async () => false))

  await join('voice-target', false, 'listener', false, true)

  expect(claim).toHaveBeenCalledWith('voice-target', false)
  expect(claim).not.toHaveBeenCalledWith('voice-target', true)
  expect(sessionJoin).not.toHaveBeenCalled()
  expect(state.value).toBe('ERROR')
})
