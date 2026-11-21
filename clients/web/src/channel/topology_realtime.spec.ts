import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { loadTopology } from './topology_client'
import { useTopologyStore } from './topology_store'

vi.mock('./topology_client', () => ({ loadTopology: vi.fn() }))
afterEach(() => vi.resetAllMocks())

it.each(['resolve', 'reject'])('fences an old socket topology %s after replacement recovery', async outcome => {
  setActivePinia(createPinia())
  const old = { revision: 1, categories: [] }, fresh = { revision: 2, categories: [] }
  let resolve!: (value: typeof old) => void, reject!: (cause: Error) => void
  vi.mocked(loadTopology).mockImplementationOnce(() => new Promise((a, b) => { resolve = a; reject = b }))
    .mockResolvedValueOnce(fresh)
  const store = useTopologyStore()
  let admitted = true
  const pending = store.refreshRealtime(() => admitted)
  admitted = false
  await store.refreshRealtime(() => true)
  expect(store.topology).toEqual(fresh)
  if (outcome === 'resolve') resolve(old)
  else reject(new Error('old socket read failed'))
  await pending
  expect(store.topology).toEqual(fresh)
  expect(store.error).toBeNull()
  expect(store.loading).toBe(false)
})

it('rejects a late topology response immediately at socket end without requiring another request', async () => {
  setActivePinia(createPinia())
  let finish!: (value: { revision: number; categories: [] }) => void
  vi.mocked(loadTopology).mockImplementationOnce(() => new Promise(resolve => { finish = resolve }))
  const store = useTopologyStore()
  let admitted = true
  const pending = store.refreshRealtime(() => admitted)
  admitted = false
  finish({ revision: 1, categories: [] }); await pending
  expect(store.topology).toBeNull()
  expect(store.error).toBeNull()
  expect(store.loading).toBe(false)
})

it('serializes ordinary UI refreshes with a live socket owner', async () => {
  setActivePinia(createPinia())
  let finish!: (value: { revision: number; categories: [] }) => void
  vi.mocked(loadTopology).mockImplementationOnce(() => new Promise(resolve => { finish = resolve }))
    .mockResolvedValueOnce({ revision: 2, categories: [] })
  const store = useTopologyStore(), current = () => true
  const socket = store.refreshRealtime(current)
  const ui = store.refresh()
  expect(loadTopology).toHaveBeenCalledTimes(1)
  finish({ revision: 1, categories: [] })
  await Promise.all([socket, ui])
  expect(loadTopology).toHaveBeenCalledTimes(2)
  expect(store.topology?.revision).toBe(2)
})

it('binds an existing UI read to socket admission without a parallel request', async () => {
  setActivePinia(createPinia())
  let finish!: (value: { revision: number; categories: [] }) => void
  vi.mocked(loadTopology).mockImplementationOnce(() => new Promise(resolve => { finish = resolve }))
  const store = useTopologyStore()
  const ui = store.refresh()
  let admitted = true
  const socket = store.refreshRealtime(() => admitted)
  expect(loadTopology).toHaveBeenCalledTimes(1)
  admitted = false
  finish({ revision: 1, categories: [] })
  await Promise.all([ui, socket])
  expect(loadTopology).toHaveBeenCalledTimes(1)
  expect(store.topology).toBeNull()
})
