import { apiBaseUrl } from '../../config/runtime'
import { tracedFetch } from '../../telemetry/client_tracing'
import { loadMessagePage, type MessageRequest } from '../../conversation/message_client'
import { searchMessages } from '../../search/search_messages_client'
export interface ArchivedChannel { id: string; name: string; description: string; category_name: string; archived_at: string }
export interface ArchivePage { revision: number; channels: ArchivedChannel[]; next_cursor?: string; can_manage: boolean }
export class ArchiveRequestError extends Error {
  constructor(readonly status: number) { super(`Не удалось загрузить архив (${status}).`) }
}
function invalid(): never { throw new Error('Сервер вернул некорректный архив.') }
export async function loadArchives(cursor?: string, request: MessageRequest = tracedFetch): Promise<ArchivePage> {
  const response = await request(`${apiBaseUrl}/archives/text-channels${cursor ? `?cursor=${encodeURIComponent(cursor)}` : ''}`, { method: 'GET', credentials: 'same-origin', headers: { accept: 'application/json' } })
  if (!response.ok) throw new ArchiveRequestError(response.status)
  const page = await response.json() as ArchivePage
  if (!page || !Number.isInteger(page.revision) || page.revision < 1 || typeof page.can_manage !== 'boolean' || !Array.isArray(page.channels) || (page.next_cursor !== undefined && typeof page.next_cursor !== 'string')) return invalid()
  for (const channel of page.channels) if (!channel || !/^[0-9a-f-]{36}$/i.test(channel.id) || typeof channel.name !== 'string' || typeof channel.description !== 'string' || typeof channel.category_name !== 'string' || !Number.isFinite(Date.parse(channel.archived_at))) return invalid()
  return page
}
export function archiveHistory(id: string, before?: string, request: MessageRequest = tracedFetch) {
  return loadMessagePage(id, before, (url, init) => request(url.replace(`${apiBaseUrl}/channels/`, `${apiBaseUrl}/archives/text-channels/`), init))
}
export function archiveSearch(id: string, query: string, before?: string, request: MessageRequest = tracedFetch) {
  return searchMessages({ query, before }, (url, init) => request(url.replace(`${apiBaseUrl}/search/messages`, `${apiBaseUrl}/archives/text-channels/${encodeURIComponent(id)}/search`), init))
}
export function archiveDownloadUrl(id: string, attachment: string): string { return `${apiBaseUrl}/archives/text-channels/${encodeURIComponent(id)}/attachments/${encodeURIComponent(attachment)}` }
export async function changeArchive(id: string, revision: number, archive: boolean, request: MessageRequest = tracedFetch): Promise<void> {
  if (!Number.isInteger(revision) || revision < 1) throw new Error('Некорректная ревизия каналов.')
  const path = archive ? `/admin/text-channels/${encodeURIComponent(id)}/readonly-archive` : `/admin/archives/text-channels/${encodeURIComponent(id)}/restore`
  const response = await request(`${apiBaseUrl}${path}`, { method: 'POST', credentials: 'same-origin', headers: { accept: 'application/json', 'content-type': 'application/json' }, body: JSON.stringify({ expected_revision: revision, ...(archive ? { confirm: true } : {}) }) })
  if (!response.ok) throw new Error(`Не удалось изменить архив (${response.status}). Обновите список каналов.`)
}
