import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import type { ProfileRequest } from '../../identity/profile_client'
import { parseGuildProfile } from '../../guild/profile/client'
export interface GuildSettings { name: string; revision: number; welcomeChannelId: string | null; afkChannelId?: string | null; afkTimeoutSeconds?: number }
export interface GuildSettingsUpdate { name: string; expected_revision: number; welcome_channel_id: string | null; afk_channel_id?: string | null; afk_timeout_seconds?: number }
export class GuildSettingsError extends Error {
  constructor(public readonly status: number) { super(status === 409 ? 'Настройки изменил другой администратор. Проверьте черновик и сохраните снова.' : `Не удалось обновить настройки (${status}).`) }
}
async function call(init: RequestInit, request: ProfileRequest): Promise<GuildSettings> {
  const response = await request(`${apiBaseUrl}/admin/guild-settings`, { ...init, credentials: 'same-origin', cache: 'no-store', headers: { accept: 'application/json', 'content-type': 'application/json' } })
  if (!response.ok) throw new GuildSettingsError(response.status)
  const body = await response.json(), profile = parseGuildProfile(body)
  if (body.welcome_channel_id !== null && (typeof body.welcome_channel_id !== 'string' || !/^[0-9a-f-]{36}$/i.test(body.welcome_channel_id))) throw new Error('Некорректный welcome-канал.')
  if (body.afk_channel_id !== null && body.afk_channel_id !== undefined && (typeof body.afk_channel_id !== 'string' || !/^[0-9a-f-]{36}$/i.test(body.afk_channel_id))) throw new Error('Некорректный AFK-канал.')
  const afkTimeoutSeconds = body.afk_timeout_seconds ?? 0
  const afkChannelId = body.afk_channel_id ?? null
  if (!Number.isInteger(afkTimeoutSeconds) || afkTimeoutSeconds < 0 || afkTimeoutSeconds > 86400 || (afkChannelId === null) !== (afkTimeoutSeconds === 0) || (afkChannelId !== null && afkTimeoutSeconds < 60)) throw new Error('Некорректный интервал AFK.')
  return { ...profile, welcomeChannelId: body.welcome_channel_id, ...(body.afk_channel_id !== undefined ? { afkChannelId: body.afk_channel_id as string | null } : {}), ...(body.afk_timeout_seconds !== undefined ? { afkTimeoutSeconds: body.afk_timeout_seconds as number } : {}) }
}
export const readGuildSettings = (request: ProfileRequest = tracedFetch) => call({ method: 'GET' }, request)
export const writeGuildSettings = (body: GuildSettingsUpdate, request: ProfileRequest = tracedFetch) => call({ method: 'PATCH', body: JSON.stringify(body) }, request)
