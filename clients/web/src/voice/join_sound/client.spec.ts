import { describe, expect, it, vi } from 'vitest'
import { JoinSoundClient } from './client'

describe('profile join sound', () => {
  it('calls the browser fetch function without a client object as its receiver', async () => {
    vi.stubGlobal('fetch', function(this: unknown) {
      expect(this).toBeUndefined()
      return Promise.resolve(new Response('', { status:404 }))
    })
    try { expect(await new JoinSoundClient('a').current()).toBeNull() }
    finally { vi.unstubAllGlobals() }
  })
  it('uploads bounded raw bytes with the captured account and no redirects', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'a', revision: 2, enabled: false })))
    const client = new JoinSoundClient('account-a', request)
    await client.upload(new Blob(['audio']))
    expect(request.mock.calls[0][1]).toMatchObject({ method: 'POST', redirect: 'error', credentials: 'same-origin', headers: { 'X-Voice-Sound-Account': 'account-a', 'content-type': 'application/octet-stream' } })
    await expect(client.upload(new Blob([new Uint8Array(2097153)]))).rejects.toThrow()
    expect(request).toHaveBeenCalledTimes(1)
  })
  it('treats missing own melody as empty and rejects rate limits', async () => {
    const client = new JoinSoundClient('a', vi.fn().mockResolvedValueOnce(new Response('', { status: 404 })).mockResolvedValueOnce(new Response('', { status: 429 })))
    expect(await client.current()).toBeNull()
    await expect(client.enable(true)).rejects.toThrow('10')
  })
})
