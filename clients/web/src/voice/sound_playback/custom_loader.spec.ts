import { expect, it, vi } from 'vitest'
import { loadJoinSound } from './custom_loader'

const id = 'fe08d4a7-89bc-46de-bb0a-a9a939778412'
it('fetches only an authenticated private id from the current deployment', async () => {
  const request = vi.fn(async (_url: string, _init: RequestInit) => new Response(new Uint8Array([1, 2]), { status: 200, headers: { 'content-type': 'audio/mpeg', 'x-content-type-options': 'nosniff' } }))
  const bytes = await loadJoinSound(id, new AbortController().signal, request)
  expect([...bytes]).toEqual([1, 2])
  const [url, init] = request.mock.calls[0]
  expect(url).toBe(`/api/v1/voice/join-sounds/${id}`)
  expect(init.credentials).toBe('same-origin'); expect(init.redirect).toBe('error'); expect(init.cache).toBe('no-store')
})

it.each(['https://evil.test/file', '../private', 'bad', `${id}?other=1`])('rejects non-UUID input before network access', async value => {
  const request = vi.fn()
  await expect(loadJoinSound(value, new AbortController().signal, request)).rejects.toThrow()
  expect(request).not.toHaveBeenCalled()
})

it('rejects oversize and unexpected content without playing it', async () => {
  const malformed = vi.fn(async () => new Response(new Uint8Array([1]), { headers: { 'content-type': 'text/html' } }))
  await expect(loadJoinSound(id, new AbortController().signal, malformed)).rejects.toThrow()
  const tooLarge = vi.fn(async () => new Response(new Uint8Array(256 * 1024 + 1), { headers: { 'content-type': 'audio/mpeg', 'x-content-type-options': 'nosniff' } }))
  await expect(loadJoinSound(id, new AbortController().signal, tooLarge)).rejects.toThrow()
})
