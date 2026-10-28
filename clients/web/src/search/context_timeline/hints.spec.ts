import { beforeEach, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { bindContextHints, useContextHints } from './hints'
import type { RealtimeEvent } from '../../realtime/realtime_client'
const event = (kind: string, id: string) => ({ eventId: 'hint', occurredAt: '2026-10-28T19:00:00Z', kind, payload: {
  channel_id: id, direct_message_id: id, message_id: 'target',
} }) as RealtimeEvent
beforeEach(() => setActivePinia(createPinia()))

for (const kind of ['CHANNEL', 'DIRECT_MESSAGE'] as const) {
  it(`${kind} context accepts only matching kind/conversation and clears on session stop`, async () => {
    const hints = useContextHints()
    const context = { open: vi.fn(async () => {}), clear: vi.fn(), refreshMessage: vi.fn(async () => {}) }
    bindContextHints(hints, { kind, conversationId: 'own', messageId: 'target' }, context)
    const prefix = kind === 'CHANNEL' ? 'message.' : 'direct_message.message_'
    await hints.apply(event(prefix + 'updated', 'other'))
    await hints.apply(event(kind === 'CHANNEL' ? 'direct_message.message_deleted' : 'message.deleted', 'own'))
    expect(context.refreshMessage).not.toHaveBeenCalled()
    await hints.apply(event(prefix + 'updated', 'own'))
    expect(context.refreshMessage).toHaveBeenLastCalledWith('target', false)
    await hints.apply(event(prefix + 'deleted', 'own'))
    expect(context.refreshMessage).toHaveBeenLastCalledWith('target', true)
    hints.reset(); expect(context.clear).toHaveBeenCalledOnce()
    await hints.apply(event(prefix + 'updated', 'own'))
    expect(context.refreshMessage).toHaveBeenCalledTimes(2)
  })
}

it('isolates subscriptions across Pinia applications and releases unmounted observers', async () => {
  const first = useContextHints(), listener = vi.fn()
  const stop = first.subscribe(listener)
  setActivePinia(createPinia())
  await useContextHints().apply(event('message.deleted', 'own'))
  expect(listener).not.toHaveBeenCalled()
  stop(); await first.apply(event('message.deleted', 'own'))
  expect(listener).not.toHaveBeenCalled()
})

it('clears retained snapshots when authenticated stores are disposed', () => {
  const hints = useContextHints(), listener = vi.fn()
  hints.subscribe(listener); hints.$dispose()
  expect(listener).toHaveBeenCalledExactlyOnceWith('reset')
})
