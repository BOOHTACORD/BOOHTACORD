import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'
import { capacityError, rateLimitError } from './authentication_flow/retry_after'

export interface AuthenticationInput {
  login: string
  password: string
}

export type AuthenticationRequest = (input: string, init: RequestInit) => Promise<Response>

async function errorMessage(response: Response): Promise<string> {
  try {
    const source: unknown = await response.json()
    if (typeof source === 'object' && source !== null && !Array.isArray(source)) {
      const error = (source as Record<string, unknown>).error
      if (typeof error === 'object' && error !== null && !Array.isArray(error)) {
        const message = (error as Record<string, unknown>).message
        if (typeof message === 'string' && message.length > 0) return message
      }
    }
  } catch {
    // The status below remains safe to display when the server has no JSON error body.
  }
  return `Не удалось выполнить запрос (${response.status}).`
}

async function send(path: string, input: AuthenticationInput, request: AuthenticationRequest): Promise<void> {
  const response = await request(`${apiBaseUrl}${path}`, {
    method: 'POST',
    credentials: 'same-origin',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify(input),
  })
  if (response.status === 429) throw rateLimitError(response)
  const busy = await capacityError(response)
  if (busy) throw busy
  if (!response.ok) throw new Error(await errorMessage(response))
}

export function login(input: AuthenticationInput, request: AuthenticationRequest = tracedFetch): Promise<void> {
  return send('/auth/login', input, request)
}

export function register(input: AuthenticationInput, request: AuthenticationRequest = tracedFetch): Promise<void> {
  if (!validCodePointLength(input.password, 12, 128)) return Promise.reject(new Error('Пароль должен содержать от 12 до 128 символов.'))
  return send('/auth/register', input, request)
}
