import { describe, it, expect, vi } from 'vitest'
import { readTelemetry, writeTelemetry } from './client'
describe('installation telemetry settings', () => {
  it('uses the protected same-origin API and never accepts credentials in state', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ installation_id: '00000000-0000-4000-8000-000000000001', mode: 'local_only', state: 'disabled', registered: false, last_accepted_at: null, queued: 0, dropped: 0 })))
    const value = await readTelemetry(request)
    expect(value.mode).toBe('local_only')
    expect(request.mock.calls[0][1]).toMatchObject({ credentials: 'same-origin', cache: 'no-store' })
    expect(value).not.toHaveProperty('credential')
  })
  it('requires explicit consent before central enrollment', async () => {
    const request = vi.fn()
    await expect(writeTelemetry({ mode: 'central', endpoint: 'https://telemetry.example.test', confirmed: false }, request)).rejects.toThrow()
    expect(request).not.toHaveBeenCalled()
  })
})
