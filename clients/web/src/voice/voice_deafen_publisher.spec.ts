import { describe, expect, it, vi } from 'vitest'
import { publishVoiceDeafened } from './voice_deafen_publisher'

describe('voice deafen publication', () => {
  it('publishes only the requested status with same-origin session credentials', async () => {
    const request = vi.fn(async () => new Response(null, { status: 204 }))
    await publishVoiceDeafened('11111111-1111-4111-8111-111111111111', true, request)
    expect(request).toHaveBeenCalledWith('/api/v1/voice/leases/11111111-1111-4111-8111-111111111111/deafen/v1', expect.objectContaining({
      method: 'PUT', credentials: 'same-origin', cache: 'no-store', body: '{"deafened":true}',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
    }))
  })

  it('surfaces a rejected server update', async () => {
    await expect(publishVoiceDeafened('11111111-1111-4111-8111-111111111111', false, async () => new Response(null, { status: 403 }))).rejects.toThrow()
  })
})
