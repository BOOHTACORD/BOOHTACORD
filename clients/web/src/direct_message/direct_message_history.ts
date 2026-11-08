import { ref } from 'vue'

import { loadDirectMessageHistory, type DirectMessageHistoryItem, type DirectMessageRequest } from './direct_message_client'
import { pendingDirectMessage, type DirectMessageDisplayItem, type PendingDirectMessageSend } from './direct_message_pending'
import { createLoadedRevisionRefresh } from '../conversation/revision_refresh/loaded'
import { trackRealtimeMessages } from '../telemetry/realtime_flow/process'
import { requestFailureFeedback, requestFailureMessage } from '../request_feedback'

export function createDirectMessageHistory(pending: Map<string, PendingDirectMessageSend>, acknowledge: (id: string) => void) {
  const directMessageId = ref<string | null>(null)
  const messages = ref<DirectMessageDisplayItem[]>([])
  const nextCursor = ref<string | undefined>()
  const newerCursor = ref<string | undefined>()
  const loadingHistory = ref(false)
  const olderLoading = ref(false)
  const newerLoading = ref(false)
  const historyLoaded = ref(false)
  const error = ref<string | null>(null)
  const retryableError = ref(false)
  const olderError = ref<string | null>(null)
  const newerError = ref<string | null>(null)
  let generation = 0
  let refreshSequence = 0
  let olderPagesLoaded = false
  let anchoredMode = false

  function mergePage(incoming: DirectMessageHistoryItem[]): void {
    const byId = new Map(messages.value.filter((message) => !message.sendStatus).map((message) => [message.id, message]))
    for (const message of incoming) {
      const current = byId.get(message.id)
      if (!current || message.revision >= current.revision) byId.set(message.id, message)
    }
    const server = [...byId.values()].sort((left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt) || right.id.localeCompare(left.id))
    for (const message of server) acknowledge(message.clientMessageId)
    const queued = [...pending].flatMap(([id, draft]) => draft.directMessageId === directMessageId.value ? [pendingDirectMessage(id, draft)] : [])
    messages.value = [...queued, ...server]
    trackRealtimeMessages(incoming)
  }

  async function open(nextDirectMessageId: string, request?: DirectMessageRequest): Promise<void> {
    if (directMessageId.value === nextDirectMessageId) return
    generation++
    directMessageId.value = nextDirectMessageId
    messages.value = []
    nextCursor.value = undefined
    newerCursor.value = undefined
    olderLoading.value = false
    newerLoading.value = false
    olderError.value = null
    newerError.value = null
    historyLoaded.value = false
    retryableError.value = false
    olderPagesLoaded = false
    anchoredMode = false
    await refreshHistory(request)
  }

  async function openAround(messageId: string, request?: DirectMessageRequest): Promise<boolean> {
    const target = directMessageId.value
    if (!target || !messageId) return false
    if (messages.value.some((message) => message.id === messageId && !message.sendStatus)) return true
    const version = ++generation
    const sequence = ++refreshSequence
    loadingHistory.value = true
    error.value = null
    retryableError.value = false
    olderLoading.value = false
    newerLoading.value = false
    olderError.value = null
    newerError.value = null
    try {
      const page = await loadDirectMessageHistory(target, undefined, request, messageId)
      if (generation !== version || directMessageId.value !== target || refreshSequence !== sequence) return false
      if (page.messages[0]?.id !== messageId) return false
      messages.value = messages.value.filter((message) => message.sendStatus)
      mergePage(page.messages)
      nextCursor.value = page.nextCursor
      newerCursor.value = messageId
      olderPagesLoaded = false
      anchoredMode = true
      historyLoaded.value = true
      return true
    } catch (cause) {
      if (generation === version && refreshSequence === sequence) {
        const feedback = requestFailureFeedback(cause, 'Не удалось открыть найденное личное сообщение.')
        error.value = feedback.message
        retryableError.value = feedback.retryable
      }
      return false
    } finally {
      if (generation === version && refreshSequence === sequence) loadingHistory.value = false
    }
  }

  function close(): void {
    generation++
    refreshSequence++
    directMessageId.value = null
    messages.value = []
    nextCursor.value = undefined
    newerCursor.value = undefined
    loadingHistory.value = false
    olderLoading.value = false
    newerLoading.value = false
    historyLoaded.value = false
    olderError.value = null
    newerError.value = null
    error.value = null
    retryableError.value = false
    olderPagesLoaded = false
    anchoredMode = false
  }

  async function refreshHistory(request?: DirectMessageRequest): Promise<void> {
    const target = directMessageId.value
    if (!target) return
    const version = generation
    const sequence = ++refreshSequence
    loadingHistory.value = true
    error.value = null
    retryableError.value = false
    try {
      const page = await loadDirectMessageHistory(target, undefined, request)
      if (generation !== version || directMessageId.value !== target || refreshSequence !== sequence) return
      const overlaps = page.messages.some(({ id }) => messages.value.some((message) => message.id === id))
      if (anchoredMode && !overlaps) { historyLoaded.value = true; return }
      mergePage(page.messages)
      if (!olderPagesLoaded && !anchoredMode) nextCursor.value = page.nextCursor
      historyLoaded.value = true
    } catch (cause) {
      if (generation === version && refreshSequence === sequence) {
        const feedback = requestFailureFeedback(cause, 'Не удалось загрузить историю личных сообщений.')
        error.value = feedback.message
        retryableError.value = feedback.retryable
      }
    } finally {
      if (generation === version && refreshSequence === sequence) loadingHistory.value = false
    }
  }

  async function loadOlder(request?: DirectMessageRequest): Promise<boolean> {
    const target = directMessageId.value
    const before = nextCursor.value
    if (!target || !historyLoaded.value || !before || olderLoading.value) return false
    const version = generation
    olderLoading.value = true
    olderError.value = null
    try {
      const page = await loadDirectMessageHistory(target, before, request)
      if (generation !== version || directMessageId.value !== target) return false
      mergePage(page.messages)
      nextCursor.value = page.nextCursor
      olderPagesLoaded = true
      return true
    } catch (cause) {
      if (generation === version) olderError.value = requestFailureMessage(cause, 'Не удалось загрузить старые личные сообщения.')
      return false
    } finally {
      if (generation === version) olderLoading.value = false
    }
  }

  async function loadNewer(request?: DirectMessageRequest): Promise<boolean> {
    const target = directMessageId.value
    const after = newerCursor.value
    if (!target || !historyLoaded.value || !after || newerLoading.value) return false
    const version = generation
    newerLoading.value = true
    newerError.value = null
    try {
      const page = await loadDirectMessageHistory(target, undefined, request, undefined, after)
      if (generation !== version || directMessageId.value !== target) return false
      mergePage(page.messages)
      newerCursor.value = page.nextCursor
      return true
    } catch (cause) {
      if (generation === version) newerError.value = requestFailureMessage(cause, 'Не удалось загрузить новые личные сообщения.')
      return false
    } finally {
      if (generation === version) newerLoading.value = false
    }
  }

  const { refreshMessage, refreshMessages } = createLoadedRevisionRefresh<DirectMessageDisplayItem, DirectMessageRequest>({ messages,
    resourceId: directMessageId, version: () => generation, load: loadDirectMessageHistory, merge: mergePage, error,
    fallback: 'Не удалось обновить личное сообщение.' })

  return { close, directMessageId, messages, nextCursor, newerCursor, loadingHistory, olderLoading, newerLoading, historyLoaded, error, retryableError, olderError, newerError, open, openAround, refreshHistory, loadOlder, loadNewer, refreshMessage, refreshMessages }
}
