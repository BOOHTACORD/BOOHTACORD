import { createPinia, setActivePinia } from 'pinia'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { useServerNotifications } from './state'
vi.mock('../remote_push/devices', () => ({ DeviceClient: class { active = false; device = null; async restore() {} async list() { return [] } cancel() {} async clear() {} } }))
function snapshot(revision = 1, enabled = false) { return { capability: { version: 1, available: true, device_transport: 'web_push' }, settings: { version: 1, revision, enabled, imported: false, dm: { mode: 'all', paused_until: null }, text: { mode: 'mentions', paused_until: null }, overrides: [] } } }
function globals() {
  setActivePinia(createPinia()); vi.stubGlobal('location', { origin: 'https://chat.example.invalid' }); vi.stubGlobal('localStorage', { getItem: () => null })
}
function json(body: unknown, status = 200) { return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } }) }
describe('server preferences lifecycle', () => {
  afterEach(() => vi.unstubAllGlobals())
  it('saves reactive settings with CAS and separate account consent', async () => {
    globals(); const request = vi.fn(async (path: string, options?: RequestInit) => {
      if (path.endsWith('/capabilities')) return json({ version: 1, account_id: 'account-a', origin: location.origin, web_push_available: false })
      if (options?.method === 'PUT') { const body = JSON.parse(String(options.body)); expect(body.expected_revision).toBe(1); expect(new Headers(options.headers).get('X-Notification-Account')).toBe('account-a'); return json(snapshot(2, true)) }
      return json(snapshot())
    }); vi.stubGlobal('fetch', request)
    const store = useServerNotifications(); await store.start('account-a'); await store.save(s => { s.enabled = true })
    expect(store.snapshot?.settings.enabled).toBe(true); expect(store.currentBinding).toBe(''); expect(store.error).toBe('')
    store.$dispose()
  })
  it('shows current server choice after conflict without replaying the write', async () => {
    globals(); let loads = 0; let writes = 0
    vi.stubGlobal('fetch', vi.fn(async (path: string, options?: RequestInit) => {
      if (path.endsWith('/capabilities')) return json({ version: 1, account_id: 'account-a', origin: location.origin, web_push_available: false })
      if (options?.method === 'PUT') { writes++; return json({}, 409) }
      return json(snapshot(++loads === 1 ? 1 : 3))
    }))
    const store = useServerNotifications(); await store.start('account-a'); await store.save(s => { s.enabled = true })
    expect(store.snapshot?.settings.revision).toBe(3); expect(store.snapshot?.settings.enabled).toBe(false); expect(writes).toBe(1); expect(store.error).toContain('другом устройстве'); store.$dispose()
  })
  it('does not apply a completed old-account load to the new profile', async () => {
    globals(); let complete!: (value: Response) => void
    const waiting = new Promise<Response>(resolve => { complete = resolve })
    vi.stubGlobal('fetch', vi.fn(async (path: string, options?: RequestInit) => {
      if (path.endsWith('/capabilities')) return json({ version: 1, account_id: 'account-b', origin: location.origin, web_push_available: false })
      if (new Headers(options?.headers).get('X-Notification-Account') === 'account-a') return waiting
      return json(snapshot(7))
    }))
    const store = useServerNotifications(); const before = store.start('account-a'); await store.start('account-b'); complete(json(snapshot(1, true))); await before
    expect(store.snapshot?.settings.revision).toBe(7); expect(store.snapshot?.settings.enabled).toBe(false); store.$dispose()
  })
})
