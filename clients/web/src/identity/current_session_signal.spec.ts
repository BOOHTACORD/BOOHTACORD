import { expect, it, vi } from 'vitest'
import { loadCurrentSession } from './current_session'

it('forwards cancellation to the session request', async () => {
  const controller = new AbortController()
  const request = vi.fn().mockResolvedValue(new Response(null, { status: 401 }))
  await expect(loadCurrentSession(request, controller.signal)).resolves.toBeNull()
  expect(request.mock.calls[0][1].signal).toBe(controller.signal)
})
