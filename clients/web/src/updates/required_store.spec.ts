import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

vi.mock('./build_identity', () => ({buildIdentity:{release_id:'r2',release_order:2,platform:'web'},buildLabel:'test'}))
vi.mock('./client', () => ({fetchUpdatePolicy:vi.fn()}))
import { fetchUpdatePolicy } from './client'
import { useUpdateStore } from './update_store'

const target = {release_id:'r5',release_order:5,minimum_release_order:4,requirements:{supported_arches:['any']},priority:'normal'} as const
const policy = {state:'published',catalog_revision:1,target} as const

describe('required update store', () => {
 beforeEach(() => { setActivePinia(createPinia()); vi.clearAllMocks(); vi.stubGlobal('location',{origin:'https://example.test'}); vi.stubGlobal('localStorage',{getItem:vi.fn(()=>null),setItem:vi.fn()}) })
 it('cannot snooze and keeps a required gate when recheck fails', async () => {
  vi.mocked(fetchUpdatePolicy).mockResolvedValueOnce(policy as never).mockRejectedValueOnce(new Error('offline'))
  const updates=useUpdateStore(); await updates.check()
  expect(updates.required).toBe(true)
  updates.later(); expect(localStorage.setItem).not.toHaveBeenCalled()
  await expect(updates.check()).rejects.toThrow('offline')
  expect(updates.required).toBe(true)
 })
 it('does not accept an older catalog during an update attempt', async () => {
  vi.mocked(fetchUpdatePolicy).mockResolvedValueOnce(policy as never).mockResolvedValueOnce({...policy,catalog_revision:0,target:null,state:'unconfigured'} as never)
  const updates=useUpdateStore(); await updates.check(); await updates.apply()
  expect(updates.required).toBe(true)
  expect(updates.policy?.catalog_revision).toBe(1)
 })
})
