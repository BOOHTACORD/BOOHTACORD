import { describe, expect, it, vi } from 'vitest'

import { login, register } from './auth_client'

describe('authentication client', () => {
  it('posts login credentials through same-origin cookies', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 204 }))

    await login({ login: 'egor', password: 'correct horse battery staple' }, request)

    expect(request).toHaveBeenCalledWith('/api/v1/auth/login', expect.objectContaining({
      method: 'POST',
      credentials: 'same-origin',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({ login: 'egor', password: 'correct horse battery staple' }),
    }))
  })

  it('returns the bounded server validation message after registration fails', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: { message: 'Этот логин уже занят' } }), { status: 409 }))

    await expect(register({ login: 'egor', password: 'correct horse battery staple' }, request)).rejects.toThrow('Этот логин уже занят')
  })

  it('explains that registration awaits initial server setup', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: { message: 'Регистрация откроется после начальной настройки сервера' } }), { status: 503 }))

    await expect(register({ login: 'member', password: 'correct horse battery staple' }, request)).rejects.toThrow('Регистрация откроется после начальной настройки сервера')
  })

  it('accepts 128 emoji as a registration password without trimming, but rejects 129 before transport', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 201 }))
    const password = ` ${'😀'.repeat(126)} `
    await register({ login: 'member', password }, request)
    expect(JSON.parse(request.mock.calls[0][1].body).password).toBe(password)
    await expect(register({ login: 'member', password: `${password}😀` }, request)).rejects.toThrow('12 до 128')
    expect(request).toHaveBeenCalledOnce()
  })

  it('rejects a short registration password before sending it, while allowing legacy login', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 204 }))
    await expect(register({ login: 'member', password: 'a'.repeat(11) }, request)).rejects.toThrow('от 12 до 128')
    expect(request).not.toHaveBeenCalled()
    await login({ login: 'member', password: 'a'.repeat(11) }, request)
    expect(request).toHaveBeenCalledOnce()
  })
})
