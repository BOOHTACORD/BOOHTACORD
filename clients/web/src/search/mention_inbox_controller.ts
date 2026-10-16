import { ref } from 'vue'
import { listMyMentions, type MentionInboxItem, type MentionInboxPage } from './mentions_inbox_client'
import { MessageRequestError } from '../conversation/message_client'

export function createMentionInboxController(load: (cursor?: string) => Promise<MentionInboxPage> = listMyMentions) {
  const mentions = ref<MentionInboxItem[]>([]), nextCursor = ref(''), loading = ref(false), error = ref('')
  let generation = 0

  async function refresh(): Promise<void> {
    const current = ++generation
    mentions.value = []; nextCursor.value = ''; loading.value = true; error.value = ''
    try {
      const page = await load()
      if (current !== generation) return
      mentions.value = page.mentions; nextCursor.value = page.nextCursor ?? ''
    } catch (cause) {
      if (current === generation) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить упоминания.'
    } finally { if (current === generation) loading.value = false }
  }

  async function loadMore(): Promise<void> {
    const cursor = nextCursor.value, current = generation
    if (!cursor || loading.value) return
    loading.value = true; error.value = ''
    try {
      const page = await load(cursor)
      if (current !== generation) return
      const seen = new Set(mentions.value.map((item) => `${item.kind}:${item.messageId}`))
      mentions.value = [...mentions.value, ...page.mentions.filter((item) => { const key = `${item.kind}:${item.messageId}`; if (seen.has(key)) return false; seen.add(key); return true })]
      nextCursor.value = page.nextCursor ?? ''
    } catch (cause) {
      if (current === generation) {
        if (cause instanceof MessageRequestError && [401, 403, 404].includes(cause.status)) { mentions.value = []; nextCursor.value = '' }
        error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить страницу.'
      }
    } finally { if (current === generation) loading.value = false }
  }

  return { mentions, nextCursor, loading, error, refresh, loadMore }
}
