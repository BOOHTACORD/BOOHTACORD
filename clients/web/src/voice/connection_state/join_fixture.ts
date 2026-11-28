import { ref, shallowRef } from 'vue'
import { vi } from 'vitest'
import type { createVoiceConnectionRevocation } from '../voice_connection_revocation'
import type { createControllerOwnership } from '../controller_ownership/state'
import { createVoiceDisconnectState } from '../disconnect_notice/state'
import type { VoiceJoinMode } from '../livekit_gateway'
import type { ActiveVoiceSession, VoiceSession } from '../voice_session'
import { createConnectionJoin } from './join'
import type { VoiceConnectionState } from './types'

export const joinedSession = {
  channelId: 'voice-target',
  leaseId: 'lease-new',
  microphone: 'LISTENER',
  room: {},
  screenProfile: null,
} as unknown as ActiveVoiceSession

export type SessionJoin = (channelId: string, transfer: boolean, mode: VoiceJoinMode, current?: () => boolean) => Promise<ActiveVoiceSession>

export function setup(sessionJoin: SessionJoin, claim = vi.fn(async (_channel: string, transfer: boolean) => !transfer)) {
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
    joinCancelled: vi.fn(() => false),
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
  return { active, error, join: join.join, state, claim, transferRequired, terminal, revocation }
}
