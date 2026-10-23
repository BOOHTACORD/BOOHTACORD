import { describe, expect, it } from 'vitest'
import { AuthenticationRateLimitError, retryAfterSeconds } from './retry_after'
import { login, register } from '../auth_client'
import { completePasswordReset } from '../password_reset_client'
import { changeOwnPassword } from '../profile_client'

describe('manual authentication rate limit feedback', () => {
  it('accepts delta seconds and future HTTP date; rejects malformed values', () => {
    const now = Date.parse('Mon, 05 Oct 2026 12:00:00 GMT')
    expect(retryAfterSeconds('42', now)).toBe(42)
    expect(retryAfterSeconds('Mon, 05 Oct 2026 12:00:31 GMT', now)).toBe(31)
    expect(retryAfterSeconds('Mon, 05 Oct 2026 11:00:00 GMT', now)).toBe(0)
    for (const value of [null, '', '-5', 'garbage', '999999999999999999999999']) {
      expect(retryAfterSeconds(value, now)).toBeNull()
    }
  })
  it('includes Retry-After for login and password-reset without retrying transport', async () => {
    for (const operation of ['login', 'reset']) {
      let calls = 0
      async function request() { calls++; return new Response(null, { status: 429, headers: { 'retry-after': '42' } }) }
      await expect(operation === 'login' ? login({ login: 'member', password: 'secret' }, request)
        : completePasswordReset('private-token', 'secret', request)).rejects.toThrow('42 с.')
      expect(calls).toBe(1)
    }
  })
  it('uses safe fallback when header is absent', () => {
    expect(new AuthenticationRateLimitError(null).message).toContain('вручную')
  })
  it('keeps AUTH_BUSY distinct and respects Retry-After without automatic retries', async () => {
    for (const operation of [login, register]) {
      let calls = 0
      const input = { login: 'synthetic-member', password: 'synthetic password' }
      const request = async () => { calls++; return busyResponse() }
      await expect(operation(input, request)).rejects.toThrow('вручную через 7 с.')
      expect(calls).toBe(1)
      expect(input.password).toBe('synthetic password')
    }
    let calls = 0
    await expect(completePasswordReset('synthetic-token', 'synthetic password', async () => { calls++; return busyResponse() })).rejects.toThrow('вручную через 7 с.')
    expect(calls).toBe(1)
    calls = 0
    await expect(changeOwnPassword('synthetic current password', 'synthetic new password', async () => { calls++; return busyResponse() })).rejects.toThrow('вручную через 7 с.')
    expect(calls).toBe(1)
  })
})

function busyResponse() {
  return new Response(JSON.stringify({ error: { code: 'AUTH_BUSY', message: 'Сервер занят.' } }), {
    status: 503, headers: { 'content-type': 'application/json', 'retry-after': '7' },
  })
}
