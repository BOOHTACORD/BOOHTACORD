import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import type { ProfileRequest } from '../../identity/profile_client'

export interface TelemetrySettings { installation_id: string; mode: 'local_only' | 'central'; state: string; registered: boolean; last_accepted_at: string | null; queued: number; dropped: number }
export interface TelemetryUpdate { mode: 'local_only' | 'central'; endpoint?: string; confirmed?: boolean }
const states = new Set(['disabled', 'unavailable', 'never_connected', 'exporting', 'degraded', 'revoked', 'stale'])
async function call(init: RequestInit, request: ProfileRequest): Promise<TelemetrySettings> {
  const response = await request(`${apiBaseUrl}/admin/telemetry`, { ...init, credentials: 'same-origin', cache: 'no-store', headers: { accept: 'application/json', 'content-type': 'application/json' } })
  if (!response.ok) throw new Error(response.status === 403 ? 'Нужны права администратора.' : 'Не удалось изменить телеметрию. Проверьте доступность центра и повторите.')
  const body = await response.json()
  if (typeof body.installation_id !== 'string' || !['local_only', 'central'].includes(body.mode) || !states.has(body.state) || typeof body.registered !== 'boolean' || !(body.last_accepted_at === null || typeof body.last_accepted_at === 'string') || !Number.isSafeInteger(body.queued) || body.queued < 0 || !Number.isSafeInteger(body.dropped) || body.dropped < 0) throw new Error('Некорректный ответ телеметрии.')
  return { installation_id: body.installation_id, mode: body.mode, state: body.state, registered: body.registered, last_accepted_at: body.last_accepted_at, queued: body.queued, dropped: body.dropped }
}
export const readTelemetry = (request: ProfileRequest = tracedFetch, signal?: AbortSignal) => call({ method: 'GET', signal }, request)
export const writeTelemetry = (body: TelemetryUpdate, request: ProfileRequest = tracedFetch, signal?: AbortSignal) => {
  if (body.mode === 'central' && body.confirmed !== true) return Promise.reject(new Error('Подтвердите отправку диагностических данных.'))
  return call({ method: 'PATCH', body: JSON.stringify(body), signal }, request)
}
