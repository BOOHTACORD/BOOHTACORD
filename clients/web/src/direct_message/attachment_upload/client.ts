import { tracedFetch } from '../../telemetry/client_tracing'
import { apiBaseUrl } from '../../config/runtime'
import { MAX_MESSAGE_ATTACHMENT_BYTES } from '../../conversation/attachment_limits'
import type { TextMessageAttachment } from '../../conversation/message_client'
import type { DirectMessageRequest } from '../direct_message_client'
import { parseDirectMessageAttachments } from '../direct_message_attachment_metadata'

export async function uploadDirectMessageAttachment(directMessageId: string, file: File, request: DirectMessageRequest = tracedFetch): Promise<TextMessageAttachment> {
  if (!directMessageId || !file.name || !Number.isInteger(file.size) || file.size < 0 || file.size > MAX_MESSAGE_ATTACHMENT_BYTES) {
    throw new Error('Файл не соответствует ограничению вложения.')
  }
  const body = new FormData()
  body.append('file', file)
  const response = await request(`${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/attachments`, {
    method: 'POST', credentials: 'same-origin', headers: { accept: 'application/json' }, body,
  })
  let result: unknown = null
  try { result = await response.json() } catch { /* A bounded status error is sufficient. */ }
  if (!response.ok) {
    const source = typeof result === 'object' && result !== null ? result as Record<string, unknown> : {}
    const error = typeof source.error === 'object' && source.error !== null ? source.error as Record<string, unknown> : {}
    const code = typeof error.code === 'string' ? `: ${error.code}` : ''
    throw Object.assign(new Error(`Не удалось загрузить вложение (${response.status}${code}).`), {
      status: response.status, code: typeof error.code === 'string' ? error.code : undefined,
    })
  }
  return parseDirectMessageAttachments([result])[0]!
}
