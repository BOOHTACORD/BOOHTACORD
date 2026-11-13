import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { memberPermissionDefaults } from './permission_keys'
import { usePermissionStore } from './permission_store'

const loadPermissions = vi.hoisted(() => vi.fn())
vi.mock('./permission_client', async (original) => ({ ...await original(), loadPermissions }))

function deferred<T>() { let resolve!: (value: T) => void; const promise = new Promise<T>((done) => { resolve = done }); return { promise, resolve } }
function snapshot(accountId: string) { return { accountId, role: 'MEMBER' as const, revision: 1, permissions: memberPermissionDefaults() } }

describe('permission store lifecycle', () => {
  beforeEach(() => {
    setActivePinia(createPinia()); loadPermissions.mockReset()
    vi.stubGlobal('window', { addEventListener: vi.fn(), removeEventListener: vi.fn() })
    vi.stubGlobal('document', { hidden: false })
  })

  it('uses one request and ignores a previous account response', async () => {
    const first = deferred<ReturnType<typeof snapshot>>(); const second = deferred<ReturnType<typeof snapshot>>()
    loadPermissions.mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise)
    const store = usePermissionStore(); store.start('account-a')
    const oldRequest = store.refresh(); expect(loadPermissions).toHaveBeenCalledOnce()
    store.start('account-b'); const newRequest = store.refresh(); expect(loadPermissions).toHaveBeenCalledTimes(2)
    first.resolve(snapshot('account-a')); await oldRequest; expect(store.snapshot).toBeNull()
    second.resolve(snapshot('account-b')); await newRequest; expect(store.snapshot?.accountId).toBe('account-b')
    store.stop()
  })

  it('supersedes an earlier request when a permission invalidation arrives', async () => {
    const first = deferred<ReturnType<typeof snapshot>>(); const second = deferred<ReturnType<typeof snapshot>>()
    loadPermissions.mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise)
    const store = usePermissionStore(); store.start('account-a')
    const pending = store.refreshRealtime()
    expect(loadPermissions).toHaveBeenCalledTimes(2)
    second.resolve({ ...snapshot('account-a'), revision: 2 }); await pending
    first.resolve(snapshot('account-a')); await Promise.resolve(); await Promise.resolve()
    expect(store.snapshot?.revision).toBe(2)
    store.stop()
  })

  it('reports an inconclusive realtime refresh as failure', async () => {
    loadPermissions.mockResolvedValueOnce(snapshot('account-a')).mockRejectedValueOnce(new Error('offline'))
    const store = usePermissionStore(); store.start('account-a'); await store.refresh()
    await expect(store.refreshRealtime()).rejects.toThrow('offline')
    store.stop()
  })
})
