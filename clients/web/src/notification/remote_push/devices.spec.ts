import { afterEach, expect, it, vi } from 'vitest'
import { DeviceClient } from './devices'
import { workerRequest, pushWorker } from './bridge'
vi.mock('./bridge', () => ({ workerRequest: vi.fn(), pushWorker: vi.fn(), applicationKey: () => new Uint8Array(65) }))
afterEach(() => { vi.unstubAllGlobals(); vi.clearAllMocks() })
it('rotates a changed browser subscription only for a previously consented issuing session, without a prompt', async () => {
  vi.stubGlobal('location', { origin: 'https://chat.example.invalid' })
  const permission = vi.fn(); vi.stubGlobal('Notification', { permission: 'granted', requestPermission: permission })
  const subscription = { toJSON: () => ({ endpoint: 'https://push.example.invalid/new', keys: { p256dh: 'synthetic', auth: 'synthetic' } }) }
  const registration = { active: {}, pushManager: { getSubscription: async () => subscription } }
  vi.stubGlobal('navigator', { serviceWorker: { getRegistration: async () => registration } })
  vi.mocked(pushWorker).mockResolvedValue(registration as any)
  const record = { epoch: 7, scope: JSON.stringify([location.origin, 'installation', 'account-a', 'session-a']), binding: 'binding', generation: 2, active: true, address_hash: 'old' }
  vi.mocked(workerRequest).mockImplementation(async (_, data) => data.type === 'READ' ? { ok: true, record } : data.type === 'SET' ? { ok: true, record: { ...record, generation: 3 } } : { ok: true })
  const old = { id: 'binding', instance_id: 'instance', state: 'active', session_ref: 'session-a', generation: 2, expires_at: new Date(Date.now() + 60000).toISOString() }
  const request = vi.fn(async (_: any, options?: RequestInit) => {
    expect(new Headers(options?.headers).get('X-Notification-Account')).toBe('account-a')
    if (options?.method === 'PUT') { expect(JSON.parse(String(options.body)).expected_generation).toBe(2); return Response.json({ account_id: 'account-a', device: { ...old, generation: 3 } }) }
    return Response.json({ version: 1, devices: [old] })
  })
  const device = new DeviceClient('account-a', { version: 1, account_id: 'account-a', origin: location.origin, installation_id: 'installation', session_ref: 'session-a', web_push_available: true, namespace: 'staging', operator_enabled: true, vapid_public_key: 'synthetic' }, request)
  await device.restore(); expect(device.active).toBe(true); expect(device.device?.generation).toBe(3); expect(permission).not.toHaveBeenCalled()
})
