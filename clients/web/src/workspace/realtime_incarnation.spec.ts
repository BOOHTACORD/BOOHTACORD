import { createPinia, setActivePinia } from 'pinia'
import { expect, it, vi } from 'vitest'
import type { RealtimeEvent } from '../realtime/realtime_client'
import type { RealtimeConnectOptions } from '../realtime/realtime_connection_types'
import { useNotificationStore } from '../notification/notification_store'
import { createWorkspaceRealtime } from './workspace_realtime'

const messageID = '22222222-2222-4222-8222-222222222222'
const channelID = '11111111-1111-4111-8111-111111111111'
function event(kind: RealtimeEvent['kind'], payload: Record<string, unknown>): RealtimeEvent {
  return { kind, payload, eventId: 'event', occurredAt: '2026-11-13T00:00:00Z' }
}
function setup() {
  setActivePinia(createPinia())
  const stores = {
    topology: { refresh: vi.fn(async () => {}), error: null },
    messages: { channelId: channelID as string | null, refresh: vi.fn(async () => {}), refreshMessages: vi.fn(async () => {}), error: null },
    directMessages: { directMessageId: channelID as string | null, refreshNavigation: vi.fn(async () => {}), refreshHistory: vi.fn(async () => {}), error: null },
  }
  let options!: RealtimeConnectOptions, deliver!: (event: RealtimeEvent) => Promise<void>
  const realtime = { connect: vi.fn((handler, _factory, _url, supplied: RealtimeConnectOptions) => { deliver = handler; options = supplied; supplied.onSocketStart?.() }), disconnect: vi.fn() }
  const workspace = createWorkspaceRealtime(stores, realtime as never, { acceptRealtimeEvent: () => false } as never,
    { active: null, refreshScreenWatchers: vi.fn() } as never, 'account', vi.fn())
  workspace.start()
  return { stores, options, deliver, workspace }
}

it('suppresses a notification whose refresh belongs to the previous socket', async () => {
  const value = setup(), notifications = useNotificationStore()
  const notify = vi.spyOn(notifications, 'deliver').mockResolvedValue()
  vi.spyOn(notifications, 'capture').mockReturnValue(0)
  let finish!: () => void
  value.stores.directMessages.refreshNavigation.mockImplementationOnce(() => new Promise<void>(resolve => { finish = resolve }))
  const pending = value.deliver(event('direct_message.message_created', { direct_message_id: channelID, message_id: messageID }))
  await vi.waitFor(() => expect(finish).toBeTypeOf('function'))
  value.options.onSocketEnd?.(); value.options.onSocketStart?.()
  finish(); await pending
  expect(notify).not.toHaveBeenCalled()
  value.workspace.stop()
})

it('does not start a follow-up edited-message refresh from an old socket', async () => {
  const value = setup()
  value.stores.directMessages.directMessageId = null
  let finish!: () => void
  value.stores.topology.refresh.mockImplementationOnce(() => new Promise<void>(resolve => { finish = resolve }))
  const pending = value.options.onHintBatch!([event('message.updated', { channel_id: channelID, message_id: messageID, revision: 2 })])
  await vi.waitFor(() => expect(finish).toBeTypeOf('function'))
  value.options.onSocketEnd?.(); value.options.onSocketStart?.()
  finish(); await pending
  expect(value.stores.messages.refreshMessages).not.toHaveBeenCalled()
  value.workspace.stop()
})
