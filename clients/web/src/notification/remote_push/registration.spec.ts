import { afterEach, expect, it, vi } from 'vitest'
import { notificationInstance } from './registration'
afterEach(() => vi.unstubAllGlobals())
it('reuses opaque instance across a lost response/reload and scopes it to the issuing profile', () => {
  const values = new Map<string, string>()
  vi.stubGlobal('localStorage', { getItem: (key: string) => values.get(key), setItem: (key: string, value: string) => values.set(key, value) })
  const first = notificationInstance('origin/install/account-a/session-a')
  expect(notificationInstance('origin/install/account-a/session-a')).toBe(first)
  expect(notificationInstance('origin/install/account-a/session-b')).not.toBe(first)
  expect(notificationInstance('origin/install/account-b/session-a')).not.toBe(first)
  for (let i = 0; i < 100; i++) notificationInstance('synthetic-' + i)
  expect(JSON.parse([...values.values()][0]).length).toBe(32)
})
