import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'

export interface CurrentSession {
  accountId: string
  role: 'MEMBER' | 'ADMINISTRATOR'
}

export type SessionRequest = (input: string, init: RequestInit) => Promise<Response>

export async function loadCurrentSession(request: SessionRequest = tracedFetch, signal?: AbortSignal): Promise<CurrentSession | null> {
  const response = await request(`${apiBaseUrl}/auth/session`, { credentials: 'same-origin', headers: { accept: 'application/json' }, ...(signal ? { signal } : {}) })
  if (response.status === 401) return null
  if (!response.ok) throw new Error(`Не удалось определить текущую сессию (${response.status}).`)
  const source: unknown = await response.json()
  if (typeof source !== 'object' || source === null || Array.isArray(source)) throw new Error('Сервер вернул некорректную сессию.')
  const value = source as Record<string, unknown>
  if (value.authenticated === false) return null
  if (typeof value.account_id !== 'string' || (value.role !== 'MEMBER' && value.role !== 'ADMINISTRATOR')) throw new Error('Сервер вернул некорректную сессию.')
  return { accountId: value.account_id, role: value.role }
}
