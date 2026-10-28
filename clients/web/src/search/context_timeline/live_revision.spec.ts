import { expect, it, vi } from 'vitest'
import { createSearchContextController } from '../search_context_controller'

const row = (id = 'target', revision = 1, deleted = false) => ({
  id, revision, deleted, body: deleted ? '' : `revision-${revision}`,
  attachments: deleted ? [] : [{ id: 'image' }], mentionUserIds: ['member'],
})
const deferred = <T>() => { let resolve!: (value: T) => void
  const promise = new Promise<T>(done => { resolve = done }); return { promise, resolve } }

it('refreshes an already open context without replacing its anchor/page', async () => {
  const load = vi.fn().mockResolvedValueOnce({ messages: [row(), row('older')] })
    .mockResolvedValueOnce({ messages: [row('target', 2), row('unrelated')] })
  const context = createSearchContextController(load)
  await context.open('target'); await context.refreshMessage('target')
  expect(context.messages.value).toEqual([row('target', 2), row('older')])
  expect(context.status.value).toBe('ready')
})

it('immediately hides deleted content and cannot resurrect it from late edit/paging reads', async () => {
  const pending = deferred<{ messages: ReturnType<typeof row>[] }>()
  const load = vi.fn().mockResolvedValueOnce({ messages: [row()] }).mockReturnValue(pending.promise)
  const context = createSearchContextController(load, { older: () => pending.promise })
  await context.open('target')
  const edit = context.refreshMessage('target')
  await context.refreshMessage('target', true)
  expect(context.messages.value[0]).toMatchObject({ deleted: true, body: '', attachments: [], mentionUserIds: [] })
  expect(context.status.value).toBe('deleted')
  pending.resolve({ messages: [row('target', 9)] }); await edit
  expect(context.messages.value[0]?.deleted).toBe(true)
})

it('keeps the highest protected revision when edit reads finish out of order', async () => {
  const pending = deferred<{ messages: ReturnType<typeof row>[] }>()
  const load = vi.fn().mockResolvedValueOnce({ messages: [row()] }).mockReturnValueOnce(pending.promise)
    .mockResolvedValueOnce({ messages: [row('target', 3)] })
  const context = createSearchContextController(load)
  await context.open('target'); const older = context.refreshMessage('target')
  await context.refreshMessage('target'); pending.resolve({ messages: [row('target', 2)] }); await older
  expect(context.messages.value[0]?.revision).toBe(3)
})

it('drops a late refresh after context/session replacement and ignores unknown IDs', async () => {
  const pending = deferred<{ messages: ReturnType<typeof row>[] }>()
  const load = vi.fn().mockResolvedValueOnce({ messages: [row()] }).mockReturnValueOnce(pending.promise)
    .mockResolvedValueOnce({ messages: [row('new')] })
  const context = createSearchContextController(load)
  await context.open('target'); const old = context.refreshMessage('target')
  await context.open('new'); pending.resolve({ messages: [row('target', 2)] }); await old
  await context.refreshMessage('unknown')
  expect(load).toHaveBeenCalledTimes(3)
  expect(context.messages.value).toEqual([row('new')])
  context.clear(); expect(context.messages.value).toEqual([])
})

it('honors a delete hint while the initial protected read is pending', async () => {
  const pending = deferred<{ messages: ReturnType<typeof row>[] }>()
  const context = createSearchContextController(() => pending.promise)
  const opening = context.open('target')
  await context.refreshMessage('target', true)
  pending.resolve({ messages: [row()] }); await opening
  expect(context.messages.value[0]).toMatchObject({ deleted: true, body: '', attachments: [] })
})

it('keeps an edit that completed before the initial older snapshot', async () => {
  const pending = deferred<{ messages: ReturnType<typeof row>[] }>()
  const load = vi.fn().mockReturnValueOnce(pending.promise).mockResolvedValueOnce({ messages: [row('target', 2)] })
  const context = createSearchContextController(load)
  const opening = context.open('target'); await context.refreshMessage('target')
  pending.resolve({ messages: [row()] }); await opening
  expect(context.messages.value[0]?.revision).toBe(2)
})

it('never rolls a refreshed/deleted row back when an older page completes', async () => {
  const pending = deferred<{ messages: ReturnType<typeof row>[] }>()
  const load = vi.fn().mockResolvedValueOnce({ messages: [row(), row('older')], nextCursor: 'older' })
    .mockResolvedValueOnce({ messages: [row('older', 3)] })
  const context = createSearchContextController(load, { older: () => pending.promise })
  await context.open('target'); const paging = context.loadOlder()
  await context.refreshMessage('older'); await context.refreshMessage('target', true)
  pending.resolve({ messages: [row('target', 2), row('older', 2)] }); await paging
  expect(context.messages.value).toMatchObject([{ id: 'target', deleted: true, body: '', attachments: [] }, { id: 'older', revision: 3 }])
})
