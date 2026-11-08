import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { firstUnreadIsVisible, newestVisibleServerMessageId, shouldAdvanceVisibleRead } from './read_visibility'

interface ReadMessage { id: string; sendStatus?: 'sending' | 'checking' | 'failed' }

export function useVisibleRead(options: {
  conversationId: () => string
  loadedConversationId: () => string | null
  messages: () => readonly ReadMessage[]
  firstUnreadMessageId?: () => string | undefined
  canRead: () => boolean
  advance: (conversationId: string, messageId: string) => Promise<boolean>
  refreshCounters: () => void
}) {
  const readRoot = ref<HTMLElement | null>(null)
  const pending = new Set<string>()
  let lastReadKey = ''

  async function markVisibleRead(): Promise<void> {
    if (!options.canRead()) return
    const conversationId = options.conversationId()
    const messages = options.messages()
    const viewport = readRoot.value?.querySelector<HTMLElement>('.message-list') ?? null
    if (!firstUnreadIsVisible(viewport, options.firstUnreadMessageId?.())) return
    const messageId = newestVisibleServerMessageId(viewport, messages)
    if (!messageId) return
    const key = `${conversationId}:${messageId}`
    if (!shouldAdvanceVisibleRead(messages, lastReadKey, conversationId, messageId) || pending.has(key)) return
    pending.add(key)
    try {
      const advanced = await options.advance(conversationId, messageId)
      if (advanced && options.conversationId() === conversationId) {
        if (shouldAdvanceVisibleRead(options.messages(), lastReadKey, conversationId, messageId)) lastReadKey = key
        options.refreshCounters()
      }
    } catch { /* Keep counters until a later visible retry. */ }
    finally { pending.delete(key) }
  }
  function queueVisibleRead(): void { void markVisibleRead() }
  watch(options.conversationId, () => { lastReadKey = '' })
  watch([options.canRead, options.conversationId, options.loadedConversationId, options.messages, options.firstUnreadMessageId ?? (() => undefined)], queueVisibleRead, { flush: 'post' })
  onMounted(() => {
    document.addEventListener('visibilitychange', queueVisibleRead)
    window.addEventListener('resize', queueVisibleRead)
    queueVisibleRead()
  })
  onBeforeUnmount(() => {
    document.removeEventListener('visibilitychange', queueVisibleRead)
    window.removeEventListener('resize', queueVisibleRead)
  })
  return { readRoot, queueVisibleRead }
}
