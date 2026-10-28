import { describe, expect, it, vi } from 'vitest'

import { ScreenPreviewRequestScopes } from './request_scopes'

describe('screen preview request scopes', () => {
  it('calls the browser fetch implementation with its global receiver', async () => {
    const request = vi.fn(function (this: unknown) {
      expect(this).toBe(globalThis)
      return Promise.resolve(new Response(null, { status: 204 }))
    })
    const scopes = new ScreenPreviewRequestScopes(request)
    const scope = scopes.create()

    await expect(scope.request('/api/v1/voice/screen-previews/v1', { method: 'GET' })).resolves.toMatchObject({ status: 204 })
    expect(request).toHaveBeenCalledOnce()
    scope.release()
  })
})
