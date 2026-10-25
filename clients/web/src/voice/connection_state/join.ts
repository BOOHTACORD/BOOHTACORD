import type { Ref } from 'vue'
import type { ActiveVoiceSession,VoiceSession } from '../voice_session'
import type { VoiceJoinMode } from '../livekit_gateway'
import type { VoiceDisconnectState } from '../disconnect_notice/state'
import type { VoiceConnectionState } from './types'
import { voiceLeaseRevocationMessage } from '../voice_lease_revocation_reason'
import type { createVoiceConnectionRevocation } from '../voice_connection_revocation'
import { VoiceRequestError } from '../admission_client'
import { voiceJoinErrorMessage } from './join_error'
import type { createControllerOwnership } from '../controller_ownership/state'
interface JoinContext {
 session:VoiceSession;terminal:VoiceDisconnectState;revocation:ReturnType<typeof createVoiceConnectionRevocation>
 active:Ref<ActiveVoiceSession|null>;state:Ref<VoiceConnectionState>;error:Ref<string|null>;deafened:Ref<boolean>
 microphoneMuted:Ref<boolean>;microphonePermissionDenied:Ref<boolean>;canJoin:Ref<boolean>;transferRequired:Ref<boolean>
 screenViewer:{start():void};volume:{start():Promise<void>};refreshAudioProcessingDiagnostics():void
 ownership:ReturnType<typeof createControllerOwnership>
}
function requiresTransfer(cause:unknown):cause is VoiceRequestError {
 return cause instanceof VoiceRequestError && cause.status===409 && ['ACTIVE_VOICE_LEASE','ORIGIN_MEDIA_BUSY'].includes(cause.code ?? '')
}
export function createConnectionJoin(context:JoinContext) {
 const {session,terminal,revocation,active,state,error,deafened,microphoneMuted,microphonePermissionDenied,canJoin,transferRequired,screenViewer,volume,refreshAudioProcessingDiagnostics}=context
  let pending:Promise<void>|null=null
  async function performJoin(channelId: string, transfer = false, joinMode: VoiceJoinMode = 'with-microphone'): Promise<void> {
    if (!canJoin.value) return

    let transferForJoin=transfer
    terminal.reset(); revocation.resetPending()
    const generation = terminal.generation
    state.value = 'JOINING'
    error.value = null
    transferRequired.value = transferForJoin
    try {
      if(!await context.ownership.claim(channelId,transferForJoin)) {
        if(transferForJoin || !await context.ownership.claim(channelId,true)) throw new VoiceRequestError(409,'ORIGIN_MEDIA_BUSY',context.ownership.otherChannelId.value ?? undefined)
        transferForJoin=true
        transferRequired.value=true
      }
      if(generation!==terminal.generation) return
      let joined:ActiveVoiceSession
      try {
        joined=await session.join(channelId,transferForJoin,joinMode)
      } catch(cause) {
        if(transferForJoin || !requiresTransfer(cause)) throw cause
        transferForJoin=true
        transferRequired.value=true
        joined=await session.join(channelId,true,joinMode)
      }
      transferRequired.value=false
      if (generation !== terminal.generation) {await session.revoke(joined.leaseId);return}
      active.value = joined
      terminal.bind(active.value.leaseId, active.value.channelId)
      const revokedReason = revocation.takeJoinRevocation(active.value.leaseId)
      if (revokedReason) { await revocation.revokeLease(active.value.leaseId, revokedReason); return }
      refreshAudioProcessingDiagnostics()
      screenViewer.start()
      await volume.start()
      if (!active.value || terminal.notice.value?.source === 'server') return
      deafened.value = false
      microphoneMuted.value = active.value.microphone === 'MUTED'
      microphonePermissionDenied.value = active.value.microphone === 'LISTENER_PERMISSION_DENIED'
      state.value = active.value.microphone === 'PUBLISHED' ? 'CONNECTED' : 'LISTENER'
    } catch (cause) {
      if (generation !== terminal.generation) return
      const cancelledReason = revocation.takeJoinRevocation(terminal.leaseID ?? '')
      active.value = null
      deafened.value = false
      microphoneMuted.value = false
      microphonePermissionDenied.value = false
      state.value = 'ERROR'
      transferRequired.value = false
      if (cancelledReason && terminal.leaseID) terminal.server(terminal.leaseID, cancelledReason)
      error.value = terminal.notice.value?.message ?? (cancelledReason ? voiceLeaseRevocationMessage(cancelledReason) : voiceJoinErrorMessage(cause))
    } finally {if(generation===terminal.generation&&!active.value) await context.ownership.release()}
  }

 function join(channelId:string,transfer=false,joinMode:VoiceJoinMode='with-microphone'):Promise<void> {
   if(pending) return pending
   const current=performJoin(channelId,transfer,joinMode).finally(()=>{if(pending===current) pending=null})
   pending=current;return current
 }
 return {join,settled:()=>pending ?? Promise.resolve()}
}
