import { apiBaseUrl } from '../../config/runtime'
import { validScreenThumbnail } from '../screen_thumbnail'

export const maxScreenPreviewBytes = 14 * 1024
export type ScreenPreviewRequest = (input: string, init: RequestInit) => Promise<Response>
export interface ScreenPreviewHint { leaseId: string; generationId: string; revision: number }
export interface ScreenPreviewFrame { revision: number; bytes: Uint8Array }
export class ScreenPreviewMissing extends Error {}

export function parseScreenPreviewHint(payload: Record<string, unknown>): ScreenPreviewHint | null {
  const { lease_id: leaseId, generation_id: generationId, revision } = payload
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  return typeof leaseId === 'string' && uuid.test(leaseId) && typeof generationId === 'string' && uuid.test(generationId) &&
    typeof revision === 'number' && Number.isSafeInteger(revision) && revision > 0
    ? { leaseId, generationId, revision } : null
}

function init(method: string, headers: Record<string, string> = {}): RequestInit {
  return { method, mode: 'same-origin', redirect: 'error', referrerPolicy: 'no-referrer', credentials: 'same-origin', cache: 'no-store', headers: { accept: 'application/json', ...headers } }
}

export async function beginScreenPreview(leaseId: string, request: ScreenPreviewRequest = fetch): Promise<string> {
  const response = await request(`${apiBaseUrl}/voice/leases/${encodeURIComponent(leaseId)}/screen-previews/v1`, init('POST'))
  if (!response.ok) throw new Error('Private screen preview is unavailable')
  const body = await response.json() as Record<string, unknown>
  if (body.schema_version !== 1 || typeof body.generation_id !== 'string' || !parseScreenPreviewHint({ lease_id: leaseId, generation_id: body.generation_id, revision: 1 })) throw new Error('Invalid screen preview generation')
  return body.generation_id
}

export async function readScreenPreview(hint: ScreenPreviewHint, afterRevision: number, request: ScreenPreviewRequest = fetch): Promise<ScreenPreviewFrame | null> {
  const query = new URLSearchParams({ after_revision: String(afterRevision) })
  const response = await request(`${apiBaseUrl}/voice/screen-previews/v1/leases/${encodeURIComponent(hint.leaseId)}/${encodeURIComponent(hint.generationId)}?${query}`, init('GET'))
  if (response.status === 204) return null
  if (response.status === 404) throw new ScreenPreviewMissing()
  const revision = Number(response.headers.get('X-Screen-Preview-Revision'))
  if (!response.ok) throw new Error('Private screen preview read failed')
  if (response.headers.get('content-type')?.split(';', 1)[0] !== 'image/jpeg' || !Number.isSafeInteger(revision) || revision <= afterRevision) return null
  const bytes = new Uint8Array(await response.arrayBuffer())
  return bytes.byteLength <= maxScreenPreviewBytes && validScreenThumbnail(bytes) ? { revision, bytes } : null
}

export async function invalidateScreenPreview(leaseId: string, generationId: string, request: ScreenPreviewRequest = fetch): Promise<void> {
  const response = await request(`${apiBaseUrl}/voice/leases/${encodeURIComponent(leaseId)}/screen-previews/v1/${encodeURIComponent(generationId)}`, init('DELETE'))
  if (!response.ok) throw new Error('Private screen preview invalidation failed')
}
