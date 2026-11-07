import { describe, expect, it, vi } from 'vitest'
import { VoiceSoundPreferences } from './state'

const response = (joined: boolean, revision = 0) => new Response(JSON.stringify({ revision, settings: { enabled: true, joined, left: true, started: true, stopped: true, allow_custom: true, volume: 50 } }), { status: 200, headers: { 'content-type': 'application/json' } })

describe('account-bound voice sound preferences', () => {
  it('uses the account fence, reads defaults and clears previous state on account change', async () => {
    const request = vi.fn().mockResolvedValueOnce(response(false)).mockResolvedValueOnce(response(true))
    const store = new VoiceSoundPreferences(request)
    await store.select('a'); expect(store.settings.value.joined).toBe(false)
    const pending = store.select('b'); expect(store.settings.value.enabled).toBe(false)
    await pending; expect(store.settings.value.joined).toBe(true)
    expect(new Headers(request.mock.calls[1][1].headers).get('X-Voice-Sound-Account')).toBe('b')
  })
  it('ignores an old account response arriving after a new selection', async () => {
    let finish!: (r: Response) => void
    const request = vi.fn().mockImplementationOnce(() => new Promise<Response>(r => { finish = r })).mockResolvedValueOnce(response(true))
    const store = new VoiceSoundPreferences(request)
    const old = store.select('a'); await store.select('b'); finish(response(false)); await old
    expect(store.settings.value.joined).toBe(true)
  })
  it('keeps explicit OFF locally on network failure and marks it unsynchronised', async () => {
    const request = vi.fn().mockResolvedValueOnce(response(true)).mockRejectedValueOnce(new Error('offline'))
    const store = new VoiceSoundPreferences(request)
    await store.select('a'); await store.patch({ enabled: false })
    expect(store.settings.value.enabled).toBe(false); expect(store.unsynchronised.value).toBe(true)
  })
  it('fails closed if server returns invalid data or an unknown field', async () => {
    const request = vi.fn().mockResolvedValue(new Response('{"revision":0,"settings":{}}'))
    const store = new VoiceSoundPreferences(request); await store.select('a')
    expect(store.settings.value.enabled).toBe(false); expect(store.unsynchronised.value).toBe(true)
  })
})

it('never re-enables an unsaved local OFF during a same-account refresh', async () => {
  const request = vi.fn().mockResolvedValueOnce(response(true)).mockRejectedValueOnce(new Error('offline')).mockResolvedValueOnce(response(true))
  const store = new VoiceSoundPreferences(request)
  await store.select('a'); await store.patch({ enabled: false }); await store.select('a')
  expect(store.settings.value.enabled).toBe(false); expect(store.unsynchronised.value).toBe(true)
})

it('does not overwrite a pending OFF with a same-account refresh', async () => {
  let finish!: (r: Response) => void
  const request = vi.fn().mockResolvedValueOnce(response(true)).mockImplementationOnce(() => new Promise<Response>(r => { finish = r })).mockResolvedValueOnce(response(true))
  const store = new VoiceSoundPreferences(request)
  await store.select('a'); const pending = store.patch({ joined: false }); await store.select('a')
  expect(store.settings.value.joined).toBe(false); finish(response(false, 1)); await pending
  expect(store.settings.value.joined).toBe(false)
})

it('keeps unsaved OFF across restart for only the same account', async () => {
  const values = new Map<string, string>()
  const storage = { getItem: (k: string) => values.get(k) ?? null, setItem: (k: string, v: string) => { values.set(k, v) }, removeItem: (k: string) => { values.delete(k) } }
  const first = new VoiceSoundPreferences(vi.fn().mockResolvedValueOnce(response(true)).mockRejectedValueOnce(new Error('offline')), storage)
  await first.select('a'); await first.patch({ enabled: false })
  const reopened = new VoiceSoundPreferences(vi.fn().mockImplementation(async () => response(true)), storage)
  await reopened.select('a'); expect(reopened.settings.value.enabled).toBe(false); expect(reopened.unsynchronised.value).toBe(true)
  await reopened.select('b'); expect(reopened.settings.value.enabled).toBe(true)
})

it('keeps local OFF if a successful response fails to acknowledge it', async () => {
  const request = vi.fn().mockResolvedValueOnce(response(true)).mockResolvedValueOnce(response(true, 1))
  const store = new VoiceSoundPreferences(request); await store.select('a'); await store.patch({ joined: false })
  expect(store.settings.value.joined).toBe(false); expect(store.unsynchronised.value).toBe(true)
})
