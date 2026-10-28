import { shallowRef, ref } from 'vue'

interface ContextItem { id: string; deleted: boolean; createdAt?: string; revision?: number }
type ContextStatus = 'idle' | 'loading' | 'ready' | 'deleted' | 'unavailable' | 'error'
interface Page<Item> { messages: Item[]; nextCursor?: string }

export function createSearchContextController<Item extends ContextItem>(load: (messageId: string) => Promise<Page<Item>>,
  paging: { newer?: (id: string) => Promise<Page<Item>>; older?: (id: string) => Promise<Page<Item>> } = {}) {
  const messages = shallowRef<Item[]>([])
  const status = ref<ContextStatus>('idle')
  const hasNewer = ref(false), olderCursor = ref<string | undefined>(), pagingError = ref(''), pagingPending = ref(false)
  let newerCursor = ''
  let sequence = 0
  let anchor = ''
  const deleted = new Set<string>()
  const refreshed = new Map<string, Item>()
  function merge(item: Item, previous?: Item): Item {
    const latest = previous && (previous.revision ?? 0) > (item.revision ?? 0) ? previous : item
    if (latest.deleted) deleted.add(latest.id)
    return deleted.has(item.id) ? { ...latest, deleted: true, body: '', attachments: [], mentionUserIds: [] } : latest
  }
  async function refreshMessage(id: string, removed = false): Promise<void> {
    if (id !== anchor && !messages.value.some(item => item.id === id)) return
    const current = sequence
    if (removed) {
      deleted.add(id)
      messages.value = messages.value.map(item => item.id === id ? merge(item) : item)
      if (id === anchor && status.value !== 'loading') status.value = 'deleted'
      return
    }
    const page = await load(id)
    if (current !== sequence) return
    const item = page.messages.find(item => item.id === id)
    if (!item) throw new Error('Сообщение больше недоступно.')
    refreshed.set(id, merge(item, refreshed.get(id)))
    messages.value = messages.value.map(previous => previous.id === id ? merge(refreshed.get(id)!, previous) : previous)
    if (id === anchor && messages.value.find(item => item.id === id)?.deleted) status.value = 'deleted'
  }

  async function open(messageId: string): Promise<void> {
    const current = ++sequence
    anchor = messageId; deleted.clear(); refreshed.clear()
    messages.value = []
    hasNewer.value = false; olderCursor.value = undefined; pagingError.value = ''; pagingPending.value = false
    status.value = 'loading'
    try {
      const page = await load(messageId)
      if (current !== sequence) return
      if (page.messages[0]?.id !== messageId) { status.value = 'unavailable'; return }
      messages.value = page.messages.map(item => merge(item, refreshed.get(item.id)))
      newerCursor = messageId; hasNewer.value = Boolean(paging.newer); olderCursor.value = page.nextCursor
      status.value = messages.value[0].deleted ? 'deleted' : 'ready'
    } catch {
      if (current === sequence) status.value = 'error'
    }
  }

  async function append(direction: 'newer' | 'older'): Promise<void> {
    const fetch = paging[direction], cursor = direction === 'newer' ? newerCursor : olderCursor.value
    if (!fetch || !cursor || pagingPending.value || (direction === 'newer' && !hasNewer.value)) return
    const current = sequence
    pagingPending.value = true; pagingError.value = ''
    try {
      const page = await fetch(cursor)
      if (current !== sequence) return
      const updates = new Map(page.messages.map(item => [item.id, merge(item, messages.value.find(previous => previous.id === item.id))])), seen = new Set<string>()
      const ordered = direction === 'newer' ? [...page.messages].reverse().concat(messages.value) : messages.value.concat(page.messages)
      messages.value = ordered.filter(item => { if (seen.has(item.id)) return false; seen.add(item.id); return true }).map(item => updates.get(item.id) ?? item)
      if (direction === 'newer') { newerCursor = page.nextCursor ?? newerCursor; hasNewer.value = Boolean(page.nextCursor) }
      else olderCursor.value = page.nextCursor
    } catch { if (current === sequence) pagingError.value = 'Не удалось загрузить страницу. Повторите попытку.' }
    finally { if (current === sequence) pagingPending.value = false }
  }
  function clear(): void { sequence++; anchor = ''; deleted.clear(); refreshed.clear(); messages.value = []; status.value = 'idle'; hasNewer.value = false; pagingPending.value = false }

  return { messages, status, hasNewer, olderCursor, pagingPending, pagingError, open, clear, refreshMessage,
    loadNewer: () => append('newer'), loadOlder: () => append('older') }
}
