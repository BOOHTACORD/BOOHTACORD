import { createPinia, setActivePinia } from 'pinia'
import { expect, it, vi } from 'vitest'
import { createMaintenanceState } from '../maintenance/state'
import type { RealtimeConnectOptions } from '../realtime/realtime_connection_types'
import type { RealtimeEvent } from '../realtime/realtime_client'
import { createWorkspaceRealtime } from './workspace_realtime'

it('routes negotiated maintenance into feature state without REST refresh', async () => {
  setActivePinia(createPinia())
  const state = createMaintenanceState()
  const stores = {
    topology: { refresh: vi.fn(async () => {}), error: null },
    messages: { channelId: null, refresh: vi.fn(async () => {}), error: null },
    directMessages: { directMessageId: null, refreshNavigation: vi.fn(async () => {}), refreshHistory: vi.fn(async () => {}), error: null },
  }
  let deliver!: (event: RealtimeEvent) => Promise<void>
  const realtime = { connect: vi.fn((handler, _factory, _url, options: RealtimeConnectOptions) => { deliver = handler; options.onSocketStart?.() }), disconnect: vi.fn() }
  const presence = { acceptRealtimeEvent: vi.fn(() => false) }
  const voice = { active: null, refreshScreenWatchers: vi.fn() }
  const workspace = createWorkspaceRealtime(stores, realtime as never, presence as never, voice as never, 'account', vi.fn(), state)
  workspace.start()
  await deliver({ eventId: 'event', occurredAt: '2026-11-09T00:00:00Z', kind: 'maintenance.snapshot', payload: { version: 1, generation: '11111111-1111-4111-8111-111111111111', revision: 1, active: true } })
  expect(state.active.value).toBe(true)
  expect(stores.topology.refresh).not.toHaveBeenCalled()
  expect(stores.directMessages.refreshNavigation).not.toHaveBeenCalled()
  workspace.stop()
})
