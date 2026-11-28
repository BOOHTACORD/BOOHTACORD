import { createVoiceDisconnectState } from './state'
import { voiceLeaseRevocationMessage, type VoiceLeaseRevocationReason } from '../voice_lease_revocation_reason'
import { unknownScreenDiagnostics } from '../screen_diagnostics'
import type { RevocationContext } from './revocation_context'
export function createVoiceConnectionRevocation(context: RevocationContext) {
  const { session, active, state, error, screenViewer, volume } = context
  const terminal = context.terminal ?? createVoiceDisconnectState()
  let pendingLocalReason: VoiceLeaseRevocationReason | null = null
  const pendingLeaseReasons = new Map<string, VoiceLeaseRevocationReason>()

  function takeJoinRevocation(leaseID: string): VoiceLeaseRevocationReason | null {
    const reason = pendingLocalReason ?? pendingLeaseReasons.get(leaseID) ?? null
    pendingLocalReason = null
    pendingLeaseReasons.clear()
    return reason
  }

  function takePostLeaveReason(leaseID: string): VoiceLeaseRevocationReason | null {
    const reason = pendingLocalReason ?? pendingLeaseReasons.get(leaseID) ?? null
    pendingLocalReason = null
    pendingLeaseReasons.clear()
    return reason
  }

  async function revokeLease(leaseID: string, reason: VoiceLeaseRevocationReason): Promise<boolean> {
    if (state.value === 'JOINING' && !active.value) {
      pendingLeaseReasons.set(leaseID, reason)
      terminal.server(leaseID, reason)
      if (pendingLeaseReasons.size > 16) pendingLeaseReasons.delete(pendingLeaseReasons.keys().next().value!)
      return false
    }
    if (active.value?.leaseId !== leaseID) {
      if (active.value || !terminal.server(leaseID, reason)) return false
      state.value = 'ERROR'; error.value = terminal.notice.value!.message; return true
    }
    terminal.bind(leaseID, active.value.channelId)
    terminal.server(leaseID, reason)
    const generation = terminal.generation
    if (state.value === 'LEAVING') { pendingLeaseReasons.set(leaseID, reason); return false }
    state.value = 'LEAVING'
    screenViewer.stop()
    volume.stop()
    try {
      await session.revoke(leaseID)
      if (active.value && active.value.leaseId !== leaseID) return false
      active.value = null
      context.refreshAudioProcessingDiagnostics()
      context.deafened.value = false
      context.microphoneMuted.value = false
      context.microphonePermissionDenied.value = false
      context.screenDiagnostics.value = unknownScreenDiagnostics()
      context.screenProfile.value = null
      context.screenState.value = 'IDLE'
      state.value = generation === terminal.generation ? 'ERROR' : 'IDLE'
      error.value = generation === terminal.generation ? terminal.notice.value?.message ?? voiceLeaseRevocationMessage(reason) : null
      return true
    } catch (cause) {
      if (generation !== terminal.generation) return false
      state.value = 'ERROR'
      error.value = terminal.notice.value?.message ?? (cause instanceof Error ? cause.message : 'Не удалось завершить локальное media-подключение.')
      return false
    }
  }

  async function disconnectLocal(reason: VoiceLeaseRevocationReason): Promise<boolean> {
    if (state.value === 'JOINING' && !active.value) { pendingLocalReason = reason; return true }
    if (state.value === 'LEAVING' && active.value) { pendingLocalReason = reason; return true }
    const leaseID = active.value?.leaseId ?? terminal.leaseID
    return leaseID ? revokeLease(leaseID, reason) : false
  }

  function resetPending(): void { pendingLocalReason = null; pendingLeaseReasons.clear() }
  function joinCancelled(leaseID: string): boolean {
    return pendingLocalReason !== null || pendingLeaseReasons.has(leaseID) || terminal.notice.value?.source === 'server'
  }
  return { joinCancelled, resetPending, disconnectLocal, revokeLease, takeJoinRevocation, takePostLeaveReason }
}
