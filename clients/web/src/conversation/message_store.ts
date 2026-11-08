import { defineStore } from 'pinia'
import { ref, watch } from 'vue'
import { createTextDelivery } from './delivery_uncertainty/text_send'

import { deleteTextMessage, editTextMessage, MessageRequestError, type MessageRequest } from './message_client'
import type { EditResult } from './message_edit_controller'
import { createTextHistory, type PendingSend } from './text_history'
import { requestFailureMessage } from '../request_feedback'

export const useMessageStore = defineStore('text-messages', () => {
  const pending = new Map<string, PendingSend>()
  const { channelId, messages, messageById, nextCursor, newerCursor, loading, olderLoading, newerLoading, historyLoaded, error, retryableError, olderError, newerError, open, openAround, refresh, loadOlder, loadNewer, setHistoryAnchor, refreshMessage, refreshMessages } = createTextHistory(pending)
  const deletedMessageIds = ref<string[]>([])
  watch(channelId, () => { deletedMessageIds.value = [] })
  const sending = ref(false)
  const retries = new Map<string, string>()

  function applyDeletedHint(targetChannelId: string, messageId: string): void {
    if (channelId.value !== targetChannelId || !messageId) return
    if (!deletedMessageIds.value.includes(messageId)) deletedMessageIds.value = [...deletedMessageIds.value, messageId]
    messages.value = messages.value.map(message => message.id === messageId && !message.deleted
      ? { ...message, body: '', deleted: true, attachments: [], mentionUserIds: [] } : message)
  }

  const { send, retry, discard } = createTextDelivery({ channelId, sending, error, messages, pending, retries })

  async function editWithResult(messageId: string, body: string, expectedRevision: number, request?: MessageRequest, mentionUserIds?: string[]): Promise<EditResult> {
    const targetChannelId = channelId.value
    if (!targetChannelId || !body) return { kind: 'stale', message: 'Сообщение недоступно.' }
    error.value = null
    try {
      const current = messages.value.find(({ id }) => id === messageId)
      const changed = await editTextMessage(targetChannelId, messageId, body, expectedRevision, request, mentionUserIds ?? current?.mentionUserIds ?? [])
      if (channelId.value !== targetChannelId) return { kind: 'stale', message: 'Беседа изменилась.' }
      messages.value = messages.value.map((message) => message.id === changed.id ? { ...changed, attachments: message.attachments } : message)
      return { kind: 'saved' }
    } catch (cause) {
      const message = cause instanceof MessageRequestError && cause.status === 409
        ? 'Сообщение изменилось. Обновите версию, чтобы сохранить свой текст.'
        : requestFailureMessage(cause, 'Не удалось изменить сообщение.')
      if (channelId.value === targetChannelId) error.value = message
      return { kind: cause instanceof MessageRequestError && cause.status === 409 ? 'conflict' : 'error', message }
    }
  }

  async function edit(messageId: string, body: string, expectedRevision: number, request?: MessageRequest, mentionUserIds?: string[]): Promise<boolean> {
    return (await editWithResult(messageId, body, expectedRevision, request, mentionUserIds)).kind === 'saved'
  }

  async function remove(messageId: string, request?: MessageRequest): Promise<boolean> {
    if (discard(messageId)) return true
    const targetChannelId = channelId.value
    if (!targetChannelId || messageId.startsWith('optimistic:')) return false
    error.value = null
    try {
      await deleteTextMessage(targetChannelId, messageId, request)
      if (channelId.value !== targetChannelId) return false
      messages.value = messages.value.map((message) => message.id === messageId && !message.deleted ? { ...message, body: '', deleted: true, attachments: [], revision: message.revision + 1 } : message)
      applyDeletedHint(targetChannelId, messageId)
      return true
    } catch (cause) {
      if (channelId.value === targetChannelId) error.value = requestFailureMessage(cause, 'Не удалось удалить сообщение.')
      return false
    }
  }

  return { applyDeletedHint, channelId, deletedMessageIds, edit, editWithResult, error, loading, olderLoading, newerLoading, historyLoaded, retryableError, olderError, newerError, loadOlder, loadNewer, messages, messageById, nextCursor, newerCursor, open, openAround, refresh, refreshMessage, refreshMessages, remove, retry, send, sending, setHistoryAnchor }
})
