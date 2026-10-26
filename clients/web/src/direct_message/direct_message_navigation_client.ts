import { parseSupportContact, type SupportContact } from '../support/contact'
import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import type { DirectMessageRequest } from './direct_message_client'

export interface DirectMessageListItem {
  id: string
  otherParticipantId: string
  otherParticipantDisplayName: string
  createdAt: string
  unreadCount: number
  mentionCount: number
  firstUnreadMessageId?: string
}

function invalid(): never { throw new Error('Сервер вернул некорректный список личных сообщений.') }
function record(value: unknown): Record<string, unknown> { return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : invalid() }
function requiredText(value: unknown): string { return typeof value === 'string' && value ? value : invalid() }
function count(value: unknown): number { return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : invalid() }

function item(value: unknown): DirectMessageListItem {
  const source = record(value)
  const createdAt = requiredText(source.created_at)
  if (Number.isNaN(Date.parse(createdAt))) invalid()
  return {
    id: requiredText(source.id), otherParticipantId: requiredText(source.other_participant_id),
    otherParticipantDisplayName: requiredText(source.other_participant_display_name), createdAt,
    unreadCount: count(source.unread_count), mentionCount: count(source.mention_count),
    ...(typeof source.first_unread_message_id === 'string' && source.first_unread_message_id ? { firstUnreadMessageId: source.first_unread_message_id } : {}),
  }
}

export async function loadDirectNavigation(request: DirectMessageRequest = tracedFetch): Promise<{items: DirectMessageListItem[]; supportContact: SupportContact}> {
  const response = await request(`${apiBaseUrl}/direct-messages`, { method: 'GET', credentials: 'same-origin', headers: { accept: 'application/json' } })
  if (!response.ok) throw new Error(`Не удалось загрузить личные сообщения (${response.status}).`)
  const source = record(await response.json())
  if (!Array.isArray(source.direct_messages)) invalid()
  return {items:source.direct_messages.map(item),supportContact:parseSupportContact(source.support_contact)}
}

export async function loadDirectMessages(request: DirectMessageRequest = tracedFetch): Promise<DirectMessageListItem[]> { return (await loadDirectNavigation(request)).items }
