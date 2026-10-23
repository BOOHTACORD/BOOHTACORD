import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { normalizeAvatarImage } from './avatar_image'
import { capacityError } from './authentication_flow/retry_after'

export interface OwnProfile { account_id: string; login: string; display_name: string; role: 'MEMBER' | 'ADMINISTRATOR'; avatar_url?: string; profile_revision?: number }
export type MemberPresence = 'online' | 'offline' | 'unknown'
export interface GuildMember { user_id: string; login: string; display_name: string; role: 'MEMBER' | 'ADMINISTRATOR'; presence: MemberPresence; avatar_url?: string; profile_revision?: number }
export interface MemberPage { members: GuildMember[]; next_cursor?: string }
export type ProfileRequest = (url: string, init: RequestInit) => Promise<Response>

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new Error('Сервер вернул некорректные данные профиля.')
  return value as Record<string, unknown>
}
function stringField(value: unknown): string { if (typeof value !== 'string') throw new Error('Сервер вернул некорректные данные профиля.'); return value }
function parseProfile(value: unknown): OwnProfile {
  const profile = record(value)
  if (profile.role !== 'MEMBER' && profile.role !== 'ADMINISTRATOR') throw new Error('Сервер вернул некорректную роль профиля.')
  return { account_id: stringField(profile.account_id), login: stringField(profile.login), display_name: stringField(profile.display_name), role: profile.role, ...(typeof profile.avatar_url === 'string' ? { avatar_url: profile.avatar_url } : {}), ...(Number.isSafeInteger(profile.profile_revision) && Number(profile.profile_revision) > 0 ? { profile_revision: Number(profile.profile_revision) } : {}) }
}
async function error(response: Response): Promise<Error> {
  try { const body = record(await response.json()); const detail = record(body.error); if (typeof detail.message === 'string') return new Error(detail.message) } catch { /* Use status-only fallback. */ }
  return new Error(`Не удалось выполнить запрос (${response.status}).`)
}
async function call(path: string, init: RequestInit, request: ProfileRequest): Promise<Response> {
  const response = await request(`${apiBaseUrl}${path}`, { ...init, credentials: 'same-origin', headers: { accept: 'application/json', ...init.headers } })
  const busy = await capacityError(response)
  if (busy) throw busy
  if (!response.ok) throw await error(response)
  return response
}
export async function loadOwnProfile(request: ProfileRequest = tracedFetch): Promise<OwnProfile> { return parseProfile(await (await call('/me', { method: 'GET' }, request)).json()) }
export async function saveOwnProfile(displayName: string, request: ProfileRequest = tracedFetch): Promise<OwnProfile> {
  return parseProfile(await (await call('/me', { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ display_name: displayName }) }, request)).json())
}
export async function changeOwnPassword(currentPassword: string, newPassword: string, request: ProfileRequest = tracedFetch): Promise<void> {
  await call('/me/password', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ current_password: currentPassword, new_password: newPassword }) }, request)
}
export async function uploadAvatar(file: File, request: ProfileRequest = tracedFetch): Promise<void> {
  const normalized = await normalizeAvatarImage(file)
  await call('/me/avatar', { method: 'PUT', headers: { 'content-type': 'image/png' }, body: normalized }, request)
}
export async function deleteAvatar(request: ProfileRequest = tracedFetch): Promise<void> { await call('/me/avatar', { method: 'DELETE' }, request) }
export async function loadMembers(cursor?: string, request: ProfileRequest = tracedFetch): Promise<MemberPage> {
  const query = new URLSearchParams({ limit: '100' }); if (cursor) query.set('cursor', cursor)
  const page = record(await (await call(`/members?${query}`, { method: 'GET' }, request)).json())
  if (!Array.isArray(page.members)) throw new Error('Сервер вернул некорректный список участников.')
  const members = page.members.map(parseMember)
  return { members, ...(typeof page.next_cursor === 'string' ? { next_cursor: page.next_cursor } : {}) }
}
export async function loadMember(userID: string, request: ProfileRequest = tracedFetch): Promise<GuildMember> {
  if (!userID) throw new Error('Не выбран участник гильдии.')
  return parseMember(await (await call(`/members/${encodeURIComponent(userID)}`, { method: 'GET' }, request)).json())
}
function parseMember(value: unknown): GuildMember {
  const member = record(value)
  if (member.role !== 'MEMBER' && member.role !== 'ADMINISTRATOR') throw new Error('Сервер вернул некорректную роль участника.')
  const presence = member.presence === 'online' || member.presence === 'offline' ? member.presence : 'unknown'
  return { user_id: stringField(member.user_id), login: stringField(member.login), display_name: stringField(member.display_name), role: member.role, presence, ...(typeof member.avatar_url === 'string' ? { avatar_url: member.avatar_url } : {}), ...(Number.isSafeInteger(member.profile_revision) && Number(member.profile_revision) > 0 ? { profile_revision: Number(member.profile_revision) } : {}) }
}
