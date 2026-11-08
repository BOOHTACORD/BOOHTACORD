import { expect, it, vi } from 'vitest'
import { VoiceSoundPreferences } from './state'

const settings = { enabled: true, joined: true, left: true, started: true, stopped: true, allow_custom: true, volume: 50 }
const response = () => new Response(JSON.stringify({ revision: 0, settings }), { status: 200 })

it('preserves an OFF chosen while the initial account request is pending', async () => {
  let finish!: (value: Response) => void
  const storage = new Map<string, string>()
  const adapter = { getItem: (key: string) => storage.get(key) ?? null, setItem: (key: string, value: string) => { storage.set(key, value) }, removeItem: (key: string) => { storage.delete(key) } }
  const store = new VoiceSoundPreferences(vi.fn(() => new Promise<Response>(resolve => { finish = resolve })), adapter)
  const loading = store.select('account-a')
  await store.patch({ enabled: false, volume: 20 })
  finish(response()); await loading
  expect(store.settings.value.enabled).toBe(false)
  expect(store.settings.value.volume).toBe(20)
  expect(store.unsynchronised.value).toBe(true)
  const reopened = new VoiceSoundPreferences(vi.fn(async () => response()), adapter)
  await reopened.select('account-a')
  expect(reopened.settings.value.enabled).toBe(false)
  expect(reopened.settings.value.volume).toBe(20)
})
