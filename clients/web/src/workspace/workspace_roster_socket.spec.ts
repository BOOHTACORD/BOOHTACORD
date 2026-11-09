import { createPinia, setActivePinia } from 'pinia'
import { expect, it, vi } from 'vitest'
import { createRosterSocketState } from '../voice/roster_socket/state'
import type { RealtimeConnectOptions } from '../realtime/realtime_connection_types'
import type { RealtimeEvent } from '../realtime/realtime_client'
import { createWorkspaceRealtime } from './workspace_realtime'

it('dispatches roster through the authenticated socket without unrelated refreshes', async () => {
  setActivePinia(createPinia())
  const reconnect = vi.fn(), roster = createRosterSocketState(reconnect)
  const stores = {
    topology: { refresh: vi.fn(async () => {}), error: null },
    messages: { channelId: null, refresh: vi.fn(async () => {}), error: null },
    directMessages: { directMessageId: null, refreshNavigation: vi.fn(async () => {}), refreshHistory: vi.fn(async () => {}), error: null },
  }
  let deliver!: (event: RealtimeEvent) => Promise<void>
  let options!: RealtimeConnectOptions
  const realtime = { connect: vi.fn((handler, _factory, _url, supplied: RealtimeConnectOptions) => { deliver = handler; options = supplied; supplied.onSocketStart?.() }), disconnect: vi.fn() }
  const presence = { acceptRealtimeEvent: vi.fn(() => false) }
  const voice = { active: null, refreshScreenWatchers: vi.fn() }
  const workspace = createWorkspaceRealtime(stores, realtime as never, presence as never, voice as never, 'account', vi.fn(), undefined, roster)
  roster.start(); workspace.start()
  await deliver({ eventId: 'event', occurredAt: '2026-11-09T00:00:00Z', kind: 'voice.roster.snapshot', payload: { version: 1, generation: '11111111-1111-4111-8111-111111111111', revision: 1, observed_at: '2026-11-09T00:00:00Z', channels: [] } })
  expect(roster.status.value).toBe('fresh_empty')
  expect(stores.topology.refresh).not.toHaveBeenCalled()
  expect(stores.directMessages.refreshNavigation).not.toHaveBeenCalled()
  options.onSocketEnd?.()
  expect(roster.status.value).toBe('stale_reconnecting')
  roster.reconnect()
  expect(reconnect).toHaveBeenCalledOnce()
  workspace.stop(); roster.stop()
})
