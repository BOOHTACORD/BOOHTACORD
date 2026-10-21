import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useTopologyStore } from './topology_store'

const topologyResponse = (revision: number) => new Response(JSON.stringify({ revision, categories: [] }))

describe('channel topology store', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('keeps topology empty and exposes a safe message when loading fails', async () => {
    const store = useTopologyStore()

    await store.refresh(async () => new Response('', { status: 401 }))

    expect(store.topology).toBeNull()
    expect(store.loading).toBe(false)
    expect(store.error).toContain('401')
  })
  it('turns a network fetch failure into localized retry guidance', async () => {
    const store = useTopologyStore()

    await store.refresh(async () => { throw new TypeError('Failed to fetch') })

    expect(store.error).toBe('Нет соединения с сервером. Проверьте подключение.')
    expect(store.error).not.toContain('Failed to fetch')
  })
  it('serializes realtime and unread refreshes and fetches the latest queued state', async () => {
    const store = useTopologyStore()
    let resolve!: (response: Response) => void
    const firstRequest = vi.fn(() => new Promise<Response>(done => { resolve = done }))
    const followup = vi.fn(async () => topologyResponse(2))
    const first = store.refresh(firstRequest)
    const second = store.refresh(followup)
    const third = store.refresh(followup)
    expect(firstRequest).toHaveBeenCalledOnce()
    expect(followup).not.toHaveBeenCalled()
    expect(store.loading).toBe(true)
    resolve(topologyResponse(1))
    await Promise.all([first, second, third])
    expect(followup).toHaveBeenCalledOnce()
    expect(store.topology?.revision).toBe(2)
    expect(store.loading).toBe(false)
    expect(store.error).toBeNull()
  })
  it('runs a queued refresh after an earlier request fails', async () => {
    const store = useTopologyStore()
    let reject!: (cause: Error) => void
    const first = store.refresh(() => new Promise<Response>((_, failed) => { reject = failed }))
    const recovery = vi.fn(async () => topologyResponse(3))
    const second = store.refresh(recovery)
    expect(recovery).not.toHaveBeenCalled()
    reject(new Error('temporary failure'))
    await Promise.all([first, second])
    expect(store.topology?.revision).toBe(3)
    expect(store.error).toBeNull()
    expect(store.loading).toBe(false)
  })
})
