import { createSSRApp, h, ref, shallowRef } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { VoiceRequestError } from '../admission_client'
import type { createVoiceConnectionRevocation } from '../voice_connection_revocation'
import type { createControllerOwnership } from '../controller_ownership/state'
import { createVoiceDisconnectState } from '../disconnect_notice/state'
import VoicePrejoin from '../VoicePrejoin.vue'
import type { VoiceJoinMode } from '../livekit_gateway'
import type { ActiveVoiceSession, VoiceSession } from '../voice_session'
import { createConnectionJoin } from './join'
import type { VoiceConnectionState } from './types'

const joinedSession = {
  channelId: 'voice-target',
  leaseId: 'lease-new',
  microphone: 'LISTENER',
  room: {},
  screenProfile: null,
} as unknown as ActiveVoiceSession

type SessionJoin = (channelId: string, transfer: boolean, mode: VoiceJoinMode) => Promise<ActiveVoiceSession>

function setup(sessionJoin: SessionJoin, claim = vi.fn(async (_channel: string, transfer: boolean) => !transfer)) {
  const active = shallowRef<ActiveVoiceSession | null>(null)
  const state = ref<VoiceConnectionState>('IDLE')
  const error = ref<string | null>(null)
  const deafened = ref(false)
  const microphoneMuted = ref(false)
  const microphonePermissionDenied = ref(false)
  const canJoin = ref(true)
  const transferRequired = ref(false)
  const terminal = createVoiceDisconnectState(() => {})
  const revocation = {
    resetPending: vi.fn(),
    takeJoinRevocation: vi.fn(() => null),
    revokeLease: vi.fn(async () => true),
  } as unknown as ReturnType<typeof createVoiceConnectionRevocation>
  const ownership = {
    claim,
    release: vi.fn(async () => {}),
    otherChannelId: ref<string | null>('voice-origin'),
  } as unknown as ReturnType<typeof createControllerOwnership>
  const session = { join: sessionJoin, revoke: vi.fn(async () => true) } as unknown as VoiceSession
  const join = createConnectionJoin({
    session,
    terminal,
    revocation,
    active,
    state,
    error,
    deafened,
    microphoneMuted,
    microphonePermissionDenied,
    canJoin,
    transferRequired,
    screenViewer: { start: vi.fn() },
    volume: { start: vi.fn(async () => {}) },
    refreshAudioProcessingDiagnostics: vi.fn(),
    ownership,
  })
  return { active, error, join: join.join, state, claim, transferRequired }
}

describe('automatic voice handoff on an explicit channel join', () => {
  beforeEach(() => vi.clearAllMocks())

  it('retries an active server lease once with transfer and preserves listener-only intent', async () => {
    const sessionJoin = vi.fn<SessionJoin>()
      .mockRejectedValueOnce(new VoiceRequestError(409, 'ACTIVE_VOICE_LEASE', 'voice-origin'))
      .mockResolvedValueOnce(joinedSession)
    const { active, join, state, claim } = setup(sessionJoin, vi.fn(async () => true))

    await join('voice-target', false, 'listener')

    expect(sessionJoin).toHaveBeenNthCalledWith(1, 'voice-target', false, 'listener')
    expect(sessionJoin).toHaveBeenNthCalledWith(2, 'voice-target', true, 'listener')
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
    expect(sessionJoin).toHaveBeenCalledWith('voice-target', true, 'listener')
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
