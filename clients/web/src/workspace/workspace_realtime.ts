import { loadCurrentSession } from '../identity/current_session'
import type { RealtimeEvent } from '../realtime/realtime_client'
import type { useRealtimeStore } from '../realtime/realtime_store'
import { useNotificationStore } from '../notification/notification_store'
import type { useGuildPresence } from '../identity/guild_presence'
import type { useVoiceConnectionStore } from '../voice/connection_store'
import { useVoiceNavigationStore } from '../voice/navigation_store'
import type { VoiceLeaseRevocationReason } from '../voice/voice_lease_revocation_reason'
import { refreshDirectMessageHint } from './direct_message_realtime'
import { refreshTopologyHint } from './topology_realtime'
import { applyVoiceLeaseRevocation } from './voice_lease_realtime'
import { applyDeletedMessageHint, shouldRefreshTextHistory } from './active_message_resync'
import { usePermissionStore } from '../authorization/permission_store'
import { notifyOwnSessionsChanged } from '../identity/own_sessions/state'
import { guildProfile } from '../guild/profile/state'
import { createProtectedRefreshGate } from './protected_refresh/gate'
import { coalesceStores } from './protected_refresh/stores'
import { refreshEditedHints } from './protected_refresh/revisions'
import { deliverProtectedHintBatch } from './protected_refresh/batch'
import { processRealtime } from '../telemetry/realtime_flow/process'
import { LatestScreenPreviewReader } from '../voice/screen_preview/reader'
import { parseScreenPreviewHint } from '../voice/screen_preview/client'
import { screenPreviewCardVisibility } from '../voice/screen_preview/visibility'
import { createMemberProfileRefresh } from './member_profile_realtime'
import { acceptNotificationHint } from '../notification/remote_push/hints'
import { useContextHints } from '../search/context_timeline/hints'
import { useMemberDirectory } from '../identity/member_directory'
import { reconcilePresenceMembers } from './presence_members'
import type { WorkspaceRealtimeStores } from './protected_refresh/types'
import { createAuthenticatedMaintenance } from '../maintenance/auth_owner'
import { createMaintenanceState } from '../maintenance/state'
import { maintenanceStateKey } from '../maintenance/context'
import { hasInjectionContext, inject } from 'vue'
import { checked, refreshProtectedState } from './protected_refresh/full'
import type { createRosterSocketState } from '../voice/roster_socket/state'
export type { WorkspaceRealtimeStores } from './protected_refresh/types'
export { refreshProtectedState } from './protected_refresh/full'
export function createWorkspaceRealtime(stores: WorkspaceRealtimeStores, realtime: ReturnType<typeof useRealtimeStore>, presence: ReturnType<typeof useGuildPresence>, voice: ReturnType<typeof useVoiceConnectionStore>, accountID: string, onSessionExpired: () => void, maintenanceState?: ReturnType<typeof createMaintenanceState>, roster?: ReturnType<typeof createRosterSocketState>) {
  let gate = createProtectedRefreshGate()
  const original = stores
  stores = coalesceStores(original, gate)
  const voiceNavigation = useVoiceNavigationStore()
  const notifications = useNotificationStore()
  const permissions = usePermissionStore()
  const refreshMemberProfile = createMemberProfileRefresh()
  const members = useMemberDirectory()
  const previews = new LatestScreenPreviewReader({
    apply: (hint, bytes) => { const active = voice.active; if (active && active.leaseId !== hint.leaseId) active.room.applyScreenPreview?.(hint.leaseId, bytes) },
    clear: leaseId => voice.active?.room.clearScreenPreview?.(leaseId),
  }, undefined, undefined, { visibility: screenPreviewCardVisibility })
  let active = false
  let lifecycle = 0
  const maintenance = createAuthenticatedMaintenance(maintenanceState ?? (hasInjectionContext() ? inject(maintenanceStateKey) : undefined) ?? createMaintenanceState())
  const contextHints = useContextHints()
  const deliver = (event: RealtimeEvent, notify = true) =>
    active ? Promise.all([onEvent(event, notify), contextHints.apply(event)]).then(() => undefined) : Promise.resolve()
  function onEvent(event: RealtimeEvent, notify = true): void | Promise<void> {
    if (!active) return
    if (maintenance.accept(event)) return
    if (roster?.accept(event)) return
    const eventLifecycle = lifecycle
    if (event.kind === 'notification.queued' || event.kind === 'notification.preferences_changed') return acceptNotificationHint(event,accountID).then(()=>undefined)
    if (presence.acceptRealtimeEvent(event)) {
      return reconcilePresenceMembers(event, members)
    }
    applyDeletedMessageHint(event, stores)
    if (event.kind === 'member.profile.updated') return refreshMemberProfile(event, stores.directMessages).then(() => undefined)
    if (event.kind === 'session.state_changed') { notifyOwnSessionsChanged(); return }
    if (event.kind === 'guild.profile.updated') return guildProfile.refresh(event.payload.revision as number)
    if (event.kind === 'connection.resync_required') return Promise.all([refreshProtectedState(stores), contextHints.recover()]).then(() => undefined)
    if (event.kind === 'direct_message.message_created' || event.kind === 'direct_message.message_updated' || event.kind === 'direct_message.message_deleted') {
      const directMessageId = event.payload.direct_message_id as string
      const previousUnread = notify ? notifications.capture(event) : null
      return refreshDirectMessageHint(stores.directMessages, directMessageId).then(() => {
        if (notify && active && lifecycle === eventLifecycle) return notifications.deliver(event, previousUnread)
      })
    }
    if (event.kind === 'channel.updated') return refreshTopologyHint(stores.topology)
    if (event.kind === 'role.permissions.updated' || event.kind === 'auth.permissions.invalidated') return permissions.refresh()
    if (event.kind === 'screen_preview.updated') { const hint = parseScreenPreviewHint(event.payload); if (hint) previews.accept(hint); return }
    if (event.kind === 'screen_preview.invalidated') { previews.invalidate(event.payload.lease_id as string, event.payload.generation_id as string); return }
    if (event.kind === 'screen_viewers.changed') return voice.refreshScreenWatchers()
    if (event.kind === 'voice.lease_revoked') return applyVoiceLeaseRevocation(voice, voiceNavigation, event.payload.lease_id as string, event.payload.reason as VoiceLeaseRevocationReason)
    if (event.kind === 'message.created' || event.kind === 'message.updated' || event.kind === 'message.deleted') {
      const previousUnread = notify ? notifications.capture(event) : null
      const visible = shouldRefreshTextHistory(event, stores.messages.channelId, Boolean(stores.directMessages.directMessageId))
      return Promise.all([
        checked(() => stores.topology.refresh(), () => stores.topology.error),
        visible ? checked(() => stores.messages.refresh(), () => stores.messages.error) : Promise.resolve(),
      ]).then(() => {
        if (notify && active && lifecycle === eventLifecycle) return notifications.deliver(event, previousUnread)
      })
    }
    return refreshProtectedState(stores)
  }

  return {
    start(): void {
      active = true
      previews.resume()
      gate = createProtectedRefreshGate(); stores = coalesceStores(original, gate)
      lifecycle += 1
      notifications.start(accountID)
      realtime.connect(event => processRealtime([event],()=>deliver(event)), undefined, undefined, {
        onHintBatch: events => processRealtime(events,()=>deliverProtectedHintBatch(events, deliver).then(() => refreshEditedHints(original, events))),
        onRecovery: () => processRealtime([],()=>Promise.all([refreshProtectedState(stores), permissions.refresh(), guildProfile.refresh(), voice.refreshScreenWatchers(), contextHints.recover()]).then(() => undefined)),
        checkSession: async signal => (await loadCurrentSession(undefined, signal))?.accountId === accountID,
        onSessionExpired,
        onSocketStart: () => { maintenance.start(); roster?.socketStart() },
        onSocketEnd: () => { maintenance.stop(); roster?.socketEnd() },
      })
    },
    stop(): void { active = false; lifecycle += 1; contextHints.reset(); previews.clear(); gate.close(); realtime.disconnect(); notifications.stop() },
  }
}
