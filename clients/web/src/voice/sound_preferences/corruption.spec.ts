import { expect, it, vi } from 'vitest'
import { VoiceSoundPreferences } from './state'

const settings = { enabled: true, joined: true, left: true, started: true, stopped: true, allow_custom: true, volume: 50 }
it.each(['{"enabled":"off"}', '{"volume":101}', '{"enabled":true}', '{"unknown":false}'])('fails closed on invalid saved safety state %s', async (raw) => {
  const storage = { getItem: () => raw, setItem: () => {}, removeItem: () => {} }
  const store = new VoiceSoundPreferences(vi.fn(async () => Response.json({ revision: 0, settings })), storage)
  await store.select('account-a')
  expect(store.settings.value.enabled).toBe(false)
  expect(store.unsynchronised.value).toBe(true)
})

it('fails closed if browser storage is inaccessible', async () => {
  vi.stubGlobal('window', { get localStorage() { throw new Error('blocked') } })
  try {
    const store = new VoiceSoundPreferences(vi.fn(async () => Response.json({ revision: 0, settings })))
    await store.select('account-a')
    expect(store.settings.value.enabled).toBe(false)
    expect(store.unsynchronised.value).toBe(true)
  } finally { vi.unstubAllGlobals() }
})
