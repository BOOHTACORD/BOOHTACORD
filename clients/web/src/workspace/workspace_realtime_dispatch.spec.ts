import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { RealtimeEvent } from '../realtime/realtime_client'
import type { RealtimeConnectOptions } from '../realtime/realtime_connection_types'
import { useNotificationStore } from '../notification/notification_store'
import { useVoiceNavigationStore } from '../voice/navigation_store'
import { usePermissionStore } from '../authorization/permission_store'
import { createWorkspaceRealtime } from './workspace_realtime'

const directID = '11111111-1111-4111-8111-111111111111'
const messageID = '22222222-2222-4222-8222-222222222222'
const leaseID = '33333333-3333-4333-8333-333333333333'

function hint(kind: RealtimeEvent['kind'], payload: Record<string, unknown>): RealtimeEvent {
  return { kind, payload, eventId: '44444444-4444-4444-8444-444444444444', occurredAt: '2026-09-25T00:00:00Z' }
}

function fixture() {
  const stores = {
    topology: { refresh: vi.fn(async () => {}), error: null },
    messages: { channelId: null as string | null, refresh: vi.fn(async () => {}), error: null },
    directMessages: { directMessageId: directID as string | null, refreshNavigation: vi.fn(async () => {}), refreshHistory: vi.fn(async () => {}), error: null },
  }
  const voice = { active: { leaseId: leaseID }, state: 'CONNECTED', refreshScreenWatchers: vi.fn(async () => {}), revokeLease: vi.fn(async () => true) }
  let deliver!: (event: RealtimeEvent) => void | Promise<void>
  const realtime = { connect: vi.fn((handler) => { deliver = handler }), disconnect: vi.fn() }
  const presence = { acceptRealtimeEvent: vi.fn(() => false) }
  const workspace = createWorkspaceRealtime(stores, realtime as never, presence as never, voice as never, 'account-1', vi.fn())
  workspace.start()
  return { stores, voice, realtime, presence, workspace, deliver: (event: RealtimeEvent) => deliver(event) }
}

describe('workspace typed realtime dispatch', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it.each(['direct_message.message_created', 'direct_message.message_updated', 'direct_message.message_deleted'] as const)('refreshes only the addressed DM on %s', async (kind) => {
    const value = fixture()
    await value.deliver(hint(kind, { direct_message_id: directID, message_id: messageID, ...(kind === 'direct_message.message_created' ? {} : { revision: 2 }) }))
    expect(value.stores.directMessages.refreshNavigation).toHaveBeenCalledOnce()
    expect(value.stores.directMessages.refreshHistory).toHaveBeenCalledOnce()
    expect(value.stores.topology.refresh).not.toHaveBeenCalled()
  })

  it('refreshes topology for channel.updated without replacing active DM history', async () => {
    const value = fixture()
    await value.deliver(hint('channel.updated', { revision: 7 }))
    expect(value.stores.topology.refresh).toHaveBeenCalledOnce()
    expect(value.stores.directMessages.refreshHistory).not.toHaveBeenCalled()
  })

  it.each(['role.permissions.updated', 'auth.permissions.invalidated'] as const)('refreshes effective permissions on %s', async (kind) => {
    const value = fixture(); const permissions = usePermissionStore(); const refresh = vi.spyOn(permissions, 'refresh').mockResolvedValue()
    await value.deliver(hint(kind, kind === 'role.permissions.updated' ? { role: 'MEMBER', revision: 8 } : {}))
    expect(refresh).toHaveBeenCalledOnce()
    expect(value.stores.topology.refresh).not.toHaveBeenCalled()
  })

  it('captures unread before a create hint and notifies only after protected refresh', async () => {
    const notifications = useNotificationStore()
    const capture = vi.spyOn(notifications, 'capture').mockReturnValue(0)
    const deliver = vi.spyOn(notifications, 'deliver').mockResolvedValue()
    const value = fixture()
    const created = hint('direct_message.message_created', { direct_message_id: directID, message_id: messageID })
    await value.deliver(created)
    expect(capture).toHaveBeenCalledWith(created)
    expect(deliver).toHaveBeenCalledWith(created, 0)
    expect(value.stores.directMessages.refreshNavigation.mock.invocationCallOrder[0]).toBeLessThan(deliver.mock.invocationCallOrder[0]!)
  })

  it('preserves one notification for a shared unread refresh instead of notifying every coalesced hint', async () => {
    const notifications = useNotificationStore()
    const capture = vi.spyOn(notifications, 'capture').mockReturnValue(0)
    const deliver = vi.spyOn(notifications, 'deliver').mockResolvedValue()
    const value = fixture()
    const options = value.realtime.connect.mock.calls[0] as unknown as [unknown, unknown, unknown, RealtimeConnectOptions]
    await options[3].onHintBatch!([0, 1, 2].map(index => ({
      ...hint('direct_message.message_created', { direct_message_id: directID, message_id: messageID }), eventId: String(index),
    })))
    expect(capture).toHaveBeenCalledOnce()
    expect(deliver).toHaveBeenCalledOnce()
  })

  it('does not deliver an old account notification after refresh finishes in a new account', async () => {
    const notifications = useNotificationStore()
    const deliver = vi.spyOn(notifications, 'deliver').mockResolvedValue()
    const value = fixture()
    let finishRefresh!: () => void
    value.stores.directMessages.refreshNavigation.mockImplementationOnce(() => new Promise<void>((resolve) => { finishRefresh = resolve }))
    const pending = value.deliver(hint('direct_message.message_created', { direct_message_id: directID, message_id: messageID }))
    await vi.waitFor(() => expect(typeof finishRefresh).toBe('function'))

    value.workspace.stop()
    createWorkspaceRealtime(value.stores, value.realtime as never, value.presence as never, value.voice as never, 'account-2', vi.fn()).start()
    finishRefresh()
    await pending

    expect(deliver).not.toHaveBeenCalled()
  })

  it('applies only the connected lease revocation and clears voice navigation', async () => {
    const value = fixture()
    const navigation = useVoiceNavigationStore()
    navigation.confirmVoiceConnected('voice-1')
    await value.deliver(hint('voice.lease_revoked', { lease_id: '55555555-5555-4555-8555-555555555555', reason: 'KICK' }))
    expect(value.voice.revokeLease).not.toHaveBeenCalled()
    expect(navigation.activeVoiceChannelId).toBe('voice-1')
    await value.deliver(hint('voice.lease_revoked', { lease_id: leaseID, reason: 'CHANNEL_CLOSED' }))
    expect(value.voice.revokeLease).toHaveBeenCalledWith(leaseID, 'CHANNEL_CLOSED')
    expect(navigation.activeVoiceChannelId).toBeNull()
  })

  it('refreshes the private screen watcher snapshot without putting account IDs in realtime', async () => {
    const value = fixture()
    await value.deliver(hint('screen_viewers.changed', {}))
    expect(value.voice.refreshScreenWatchers).toHaveBeenCalledOnce()
  })
})
