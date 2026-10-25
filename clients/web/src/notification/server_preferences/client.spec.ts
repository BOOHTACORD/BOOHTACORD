import { expect, it, vi } from 'vitest'
import { createNotificationPreferencesClient, PreferenceError, type Settings } from './client'
import { previewLegacyPreferences } from './migration'

const settings: Settings = { version: 1, revision: 2, enabled: false, imported: false, dm: { mode: 'all', paused_until: null }, text: { mode: 'mentions', paused_until: null }, overrides: [] }
const snapshot = { capability: { version: 1, available: false, device_transport: 'unavailable' }, settings }
it('stops probing an old server and blocks unsupported mutations', async () => {
  const fetcher = vi.fn(async () => new Response('{}', { status: 404 }))
  const client = createNotificationPreferencesClient(fetcher)
  expect(await client.load()).toBeNull(); expect(await client.load()).toBeNull()
  await expect(client.save(settings, 2)).rejects.toBeInstanceOf(PreferenceError)
  expect(fetcher).toHaveBeenCalledTimes(1)
})
it('round trips server version and forwards explicit revision conflicts', async () => {
  const fetcher = vi.fn(async (_url: string | URL | Request, options?: RequestInit) => options?.method === 'PUT' ? new Response('{}', { status: 409 }) : new Response(JSON.stringify(snapshot)))
  const client = createNotificationPreferencesClient(fetcher)
  expect((await client.load())?.settings.revision).toBe(2)
  await expect(client.save(settings, 2)).rejects.toMatchObject({ status: 409 })
  const body = JSON.parse(String(fetcher.mock.calls[1][1]?.body))
  expect(body.expected_revision).toBe(2); expect(body.account_id).toBeUndefined()
})
it('fails safely on an incompatible response', async () => {
  const client = createNotificationPreferencesClient(vi.fn(async () => new Response(JSON.stringify({ ...snapshot, capability: { ...snapshot.capability, version: 2 } }))))
  await expect(client.load()).rejects.toThrow()
})
it('does not import implicit all or enable delivery', () => {
  expect(previewLegacyPreferences({ getItem: () => null }, 'account')).toEqual({ overrides: [], local_disabled: false, source_present: false, errors: [] })
  const stored = { 'CHANNEL:11111111-1111-4111-8111-111111111111': { mode: 'none', pausedUntil: 0 } }
  const result = previewLegacyPreferences({ getItem: key => key.endsWith(':enabled') ? '0' : JSON.stringify(stored) }, 'account')
  expect(result.local_disabled).toBe(true); expect(result.overrides).toHaveLength(1); expect(result.overrides[0].mode).toBe('none')
  expect('enabled' in result).toBe(false)
})
it('rejects corrupted local data without partially importing it', () => {
  const result = previewLegacyPreferences({ getItem: () => '{broken' }, 'account')
  expect(result.overrides).toHaveLength(0); expect(result.errors).toHaveLength(1)
})
