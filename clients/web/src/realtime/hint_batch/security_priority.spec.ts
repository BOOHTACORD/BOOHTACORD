import { afterEach, expect, it, vi } from 'vitest'
import type { RealtimeEvent } from '../realtime_client'
import { createCoalescedDelivery } from './controller'

afterEach(() => vi.useRealTimers())
const event = (kind: RealtimeEvent['kind'], id: string): RealtimeEvent => ({
  eventId: id, kind, occurredAt: '2026-11-13T00:00:00Z', payload: {},
})

it('delivers security hints ahead of a full blocked batch without racing permission refreshes', async () => {
  vi.useFakeTimers()
  let finishBatch!: () => void, finishPermission!: () => void
  const pendingBatch = new Promise<void>(resolve => { finishBatch = resolve })
  const pendingPermission = new Promise<void>(resolve => { finishPermission = resolve })
  const applied: string[] = []
  const onEvent = vi.fn((value: RealtimeEvent) => {
    applied.push(value.eventId)
    return value.eventId === 'permission-1' ? pendingPermission : undefined
  })
  const failure = vi.fn(), delivery = createCoalescedDelivery(onEvent, undefined, failure, () => pendingBatch)
  for (let i = 0; i < 128; i++) delivery.accept(event('message.created', `first-${i}`))
  await vi.advanceTimersByTimeAsync(30)
  for (let i = 0; i < 128; i++) delivery.accept(event('message.created', `next-${i}`))
  delivery.accept(event('auth.permissions.invalidated', 'permission-1'))
  delivery.accept(event('role.permissions.updated', 'permission-2'))
  delivery.accept(event('session.state_changed', 'session'))
  delivery.accept(event('voice.lease_revoked', 'revoke'))
  expect(applied).toEqual(['permission-1', 'session', 'revoke'])
  finishPermission(); await vi.advanceTimersByTimeAsync(1)
  expect(applied).toEqual(['permission-1', 'session', 'revoke', 'permission-2'])
  finishBatch(); await vi.advanceTimersByTimeAsync(1)
  expect(applied).toEqual(['permission-1', 'session', 'revoke', 'permission-2'])
  expect(failure).not.toHaveBeenCalled()
  delivery.reset()
})

it('fails closed immediately when a permission refresh fails behind a blocked batch', async () => {
  vi.useFakeTimers()
  let finish!: () => void
  const failure = vi.fn(), delivery = createCoalescedDelivery(
    () => Promise.reject(new Error('permission check failed')), undefined, failure,
    () => new Promise<void>(resolve => { finish = resolve }),
  )
  delivery.accept(event('message.created', 'blocked'))
  await vi.advanceTimersByTimeAsync(30)
  delivery.accept(event('auth.permissions.invalidated', 'permission'))
  await vi.advanceTimersByTimeAsync(1)
  expect(failure).toHaveBeenCalledOnce()
  expect(delivery.cursor()).toBeNull()
  finish(); await vi.advanceTimersByTimeAsync(1)
  expect(failure).toHaveBeenCalledOnce()
  delivery.reset()
})

it('does not start an old queued permission refresh after disconnection', async () => {
  vi.useFakeTimers()
  let finish!: () => void
  const applied: string[] = []
  const delivery = createCoalescedDelivery(value => {
    applied.push(value.eventId)
    return value.eventId === 'old-1' ? new Promise<void>(resolve => { finish = resolve }) : undefined
  }, undefined, vi.fn(), vi.fn())
  delivery.accept(event('auth.permissions.invalidated', 'old-1'))
  delivery.accept(event('role.permissions.updated', 'old-2'))
  delivery.disconnected()
  delivery.accept(event('auth.permissions.invalidated', 'new'))
  finish(); await vi.advanceTimersByTimeAsync(1)
  expect(applied).toEqual(['old-1', 'new'])
  delivery.reset()
})
